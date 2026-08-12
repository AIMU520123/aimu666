import SwiftUI

/// 占卜交互界面 — 三硬币法模拟
///
/// 在 App 中作为二级/三级入口（从 TodayReflectionView 的隐藏菜单进入）。
/// 不在主 Tab 中显示 — 规避 Apple 4.3(b) 审核风险。
///
/// 交互流程：
/// 1. 用户可选填问题
/// 2. 6轮掷币（每轮自动生成3枚硬币的正反面）
/// 3. 动画展示掷币过程
/// 4. 显示结果：卦象符号 + 名称 + 核心含义
/// 5. 可选："与Yi深入探讨此卦"
///
/// 设计意图：
/// - 让占卜成为一个有仪式感但不神秘化的过程
/// - 强调 "卦象是镜子，不是预言"
/// - 掷币过程使用中式水墨动画风格
struct CastingView: View {
    @Binding var userProfile: UserProfile

    @Environment(\.dismiss) var dismiss
    @Environment(\.appTheme) var theme
    @Environment(AppState.self) var appState

    @State private var castingPhase: CastingPhase = .preparation

    /// 用户问题（可选）
    @State private var userQuestion: String = ""

    /// 6轮掷币结果
    @State private var tossResults: [CoinTossResult] = []

    /// 当前轮次（1-6）
    @State private var currentRound: Int = 0

    /// 生成的六爻（true=阳, false=阴）
    @State private var generatedLines: [Bool] = []

    /// 本卦
    @State private var primaryHexagram: Hexagram?

    /// 变卦
    @State private var transformedHexagram: Hexagram?

    /// 变爻索引
    @State private var changingIndices: [Int] = []

    /// 掷币动画状态
    @State private var isTossing: Bool = false

    /// 当前显示的3枚硬币
    @State private var currentCoins: [CoinFace] = [.heads, .heads, .heads]

    /// 动画计时器
    @State private var animationTimer: Timer?

    /// 结果展示延迟
    @State private var showResult: Bool = false

    /// 与 Yi 深入探讨此卦：sheet 打开已锚定本次起卦的对话
    @State private var discussCasting: CastingResult? = nil

    private let matcher = HexagramMatcher.shared
    private let dataStore = HexagramDataStore.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 进度指示器
                progressIndicator

                ScrollView {
                    VStack(spacing: 24) {
                        switch castingPhase {
                        case .preparation:
                            preparationView
                        case .casting:
                            castingView
                        case .result:
                            resultView
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                }
            }
            .background(theme.palette.backgroundGradient)
            .navigationTitle(UserDefaultsManager.shared.softenDivinationLanguage ? "Reflect" : "Casting")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $discussCasting) { cr in
                ChatView(userProfile: $userProfile, initialCasting: cr)
            }
        }
    }

    // MARK: - 准备阶段

    private var preparationView: some View {
        VStack(spacing: 28) {
            // 引导文案
            VStack(spacing: 12) {
                Text("The Three Coins Method")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(theme.palette.ink)

                Text("""
                    In the ancient tradition, three coins are tossed six times \
                    to build a hexagram — one line at a time, from the bottom up.

                    Each toss reflects not the future, but the present state \
                    of your heart. The hexagram is a mirror.
                    """)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            // 问题输入（可选）
            VStack(alignment: .leading, spacing: 8) {
                Text("What's on your mind? (optional)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                TextField("E.g., What should I focus on right now?", text: $userQuestion)
                    .textFieldStyle(.roundedBorder)
                    .font(.body)
            }

            Spacer().frame(height: 20)

            // 开始掷币按钮（免费额度拦截：非买断用户累计起卦达上限后引导付费墙）
            Button {
                let store = StoreManager.shared
                let overQuota = !store.isPremium && userProfile.castsUsedTotal >= UserProfile.freeCastAllowance
                if overQuota {
                    appState.showPaywall = true
                    return
                }
                userProfile.castsUsedTotal += 1
                try? DatabaseManager.shared.saveUserProfile(userProfile)
                withAnimation(.easeInOut) {
                    castingPhase = .casting
                    currentRound = 1
                    simulateToss()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "hand.draw")
                    Text("Begin Casting")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(theme.palette.ink)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(.top, 20)
    }

    // MARK: - 掷币阶段

    private var castingView: some View {
        VStack(spacing: 32) {
            // 当前轮次标题
            Text("Toss \(currentRound) of 6")
                .font(.headline)
                .foregroundColor(theme.palette.ink)

            // 硬币展示（3枚）
            HStack(spacing: 20) {
                ForEach(currentCoins.indices, id: \.self) { index in
                    coinView(face: currentCoins[index], isAnimating: isTossing)
                }
            }
            .padding(.vertical, 40)

            // 已生成的爻线
            if !generatedLines.isEmpty {
                VStack(spacing: 0) {
                    Text("Building the hexagram...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 12)

                    HexagramLinesView(lines: generatedLines)
                        .frame(height: min(60, CGFloat(generatedLines.count * 16)))
                }
            }

            // 掷币按钮
            if !isTossing {
                Button {
                    simulateToss()
                } label: {
                    Text(currentRound <= 6 ?
                         "Toss the Coins" :
                         "Complete Casting")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(theme.palette.ink)
                        .foregroundColor(theme.palette.textOnAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            } else {
                ProgressView()
                    .scaleEffect(1.2)
            }
        }
    }

    // MARK: - 结果阶段

    private var resultView: some View {
        VStack(spacing: 24) {
            // 卦象符号
            if let hex = primaryHexagram {
                Text(hex.symbol)
                    .font(.system(size: 96))
                    .foregroundColor(theme.palette.ink)
                    .padding(.top, 20)

                Text(hex.nameEN)
                    .font(.title)
                    .fontWeight(.medium)
                    .foregroundColor(theme.palette.ink)

                Text(hex.nameCN)
                    .font(.title2)
                    .foregroundColor(.secondary)

                // 核心含义
                Text(hex.coreMeaning)
                    .font(.body)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal)

                // 爻线显示
                HexagramLinesView(lines: hex.lines)
                    .frame(height: 80)

                // 变爻信息
                if !changingIndices.isEmpty, let changed = transformedHexagram {
                    VStack(spacing: 8) {
                        Text("Changing Lines")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text(changingIndices.map { "Line \($0 + 1)" }.joined(separator: ", "))
                            .font(.body)
                            .foregroundColor(theme.palette.ink)

                        Text("Transforms to: \(changed.nameEN)")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(theme.palette.ink.opacity(0.05))
                    )
                }

                // 变爻真爻辞（确定性拼接，根治 3B 模型编造爻辞）
                if !changingIndices.isEmpty, let hex = primaryHexagram {
                    let yaoTexts = changingIndices.compactMap { idx -> (Int, String)? in
                        guard let t = IChingCorpus.shared.lineText(hexagramID: hex.id, line: idx + 1) else { return nil }
                        return (idx + 1, t)
                    }
                    if !yaoTexts.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("The Changing Line(s)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(theme.palette.ink)

                            ForEach(Array(yaoTexts.enumerated()), id: \.offset) { _, pair in
                                let (lineNo, text) = pair
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Line \(lineNo) (yao ci)")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(theme.palette.ink)
                                    Text(text)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                        .lineSpacing(4)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(theme.palette.ink.opacity(0.15), lineWidth: 1)
                        )
                    }
                }

                // 卦辞
                VStack(alignment: .leading, spacing: 8) {
                    Text("The Judgement")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(theme.palette.ink)

                    Text(hex.judgementEN)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineSpacing(4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(theme.palette.ink.opacity(0.15), lineWidth: 1)
                )
            }

            // 下一步引导（P2：起卦后给明确"下一步"，降低新手茫然）
            nextStepGuidance

            // 操作按钮
            VStack(spacing: 12) {
                // 保存结果
                Button {
                    saveCastingResult()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "bookmark")
                        Text("Save to Collection")
                    }
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(theme.palette.ink)
                    .foregroundColor(theme.palette.textOnAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                // 再次占卜
                Button {
                    resetCasting()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Cast Again")
                    }
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(theme.palette.ink.opacity(0.3), lineWidth: 1)
                    )
                }
                .foregroundColor(theme.palette.ink)

                // 与 Yi 深入探讨此卦：对话将锚定本次起卦，连续展开并保持易经逻辑
                Button {
                    if let cr = makeCastingResult() {
                        discussCasting = cr
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                        Text("Discuss with Yi")
                    }
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(theme.palette.accent)
                    .foregroundColor(theme.palette.textOnAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .opacity(showResult ? 1 : 0)
        .animation(.easeInOut(duration: 0.8), value: showResult)
    }

    // MARK: - 下一步引导

    /// 起卦完成后的轻量引导：把"保存 / 问 Yi / 设为今日"三个动作显性化
    private var nextStepGuidance: some View {
        HStack(spacing: 8) {
            Image(systemName: "lightbulb")
                .font(.subheadline)
                .foregroundColor(theme.palette.accent)
            Text(UserDefaultsManager.shared.softenDivinationLanguage
                 ? "Keep this reading, talk it through with Yi, or return to today's reflection."
                 : "Save it to your Collection, discuss it with Yi, or go back to today's reflection.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.palette.ink.opacity(0.04))
        )
    }

    // MARK: - 进度指示器

    private var progressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<6, id: \.self) { index in
                Circle()
                    .fill(circleColor(for: index))
                    .frame(width: 10, height: 10)
            }
        }
        .padding(.vertical, 12)
    }

    private func circleColor(for index: Int) -> Color {
        if castingPhase == .result {
            return theme.palette.ink
        }
        if index < currentRound - 1 {
            return theme.palette.ink
        }
        if index == currentRound - 1 && castingPhase == .casting {
            return theme.palette.ink.opacity(0.5)
        }
        return theme.palette.ink.opacity(0.15)
    }

    // MARK: - 硬币视图

    private func coinView(face: CoinFace, isAnimating: Bool) -> some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 64, height: 64)
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)

            if face == .heads {
                Image(systemName: "circle.fill")
                    .font(.title)
                    .foregroundColor(theme.palette.ink)
            } else {
                Image(systemName: "circle")
                    .font(.title)
                    .foregroundColor(theme.palette.ink)
            }
        }
        .rotation3DEffect(
            .degrees(isAnimating ? 720 : 0),
            axis: (x: 0, y: 1, z: 0)
        )
        .animation(
            .easeInOut(duration: 0.6).repeatCount(3, autoreverses: true),
            value: isAnimating
        )
    }

    // MARK: - 掷币逻辑

    private func simulateToss() {
        guard currentRound <= 6, !isTossing else { return }

        isTossing = true
        showResult = false

        // 动画阶段：随机翻转硬币
        var flips = 0
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { timer in
            currentCoins = (0..<3).map { _ in Bool.random() ? .heads : .tails }
            flips += 1
            if flips >= 8 {
                timer.invalidate()
                // 最终结果
                let result = CoinTossResult(
                    id: currentRound,
                    coins: currentCoins
                )
                tossResults.append(result)
                generatedLines.append(result.lineValue.isYang)

                if result.lineValue.isChanging {
                    changingIndices.append(currentRound - 1)
                }

                isTossing = false

                if currentRound < 6 {
                    currentRound += 1
                } else {
                    completeCasting()
                }
            }
        }
    }

    private func completeCasting() {
        // 计算卦象
        if let hex = matcher.matchPrimaryHexagram(from: generatedLines) {
            primaryHexagram = hex
        }

        if !changingIndices.isEmpty {
            transformedHexagram = matcher.transformedHexagram(
                from: generatedLines, changingIndices: changingIndices
            )
        }

        // 解锁卦象
        if let hexID = primaryHexagram?.id {
            if matcher.shouldUnlock(hexagramID: hexID, userProfile: userProfile) {
                userProfile.unlockedHexagramIDs.insert(hexID)
                do {
                    try DatabaseManager.shared.unlockHexagram(
                        id: hexID, method: "casting"
                    )
                } catch {
                    print("Failed to unlock hexagram: \(error)")
                }
            }
        }

        withAnimation {
            castingPhase = .result
        }

        // 延迟展示结果
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation {
                showResult = true
            }
        }
    }

    /// 构造本次起卦结果（供"保存到收藏"与"与 Yi 探讨"共用）
    private func makeCastingResult() -> CastingResult? {
        guard let hex = primaryHexagram else { return nil }
        return CastingResult(
            tossResults: tossResults,
            generatedLines: generatedLines,
            changingLineIndices: changingIndices,
            primaryHexagramID: hex.id,
            transformedHexagramID: transformedHexagram?.id,
            nuclearHexagramID: matcher.nuclearHexagram(from: generatedLines)?.id ?? hex.id,
            userQuestion: userQuestion.isEmpty ? nil : userQuestion,
            isSaved: false
        )
    }

    private func saveCastingResult() {
        guard let result = makeCastingResult() else { return }
        var saved = result
        saved.isSaved = true

        do {
            try DatabaseManager.shared.saveCastingResult(saved)
        } catch {
            print("Failed to save casting result: \(error)")
        }

        dismiss()
    }

    private func resetCasting() {
        withAnimation {
            castingPhase = .preparation
            tossResults = []
            generatedLines = []
            changingIndices = []
            currentRound = 0
            primaryHexagram = nil
            transformedHexagram = nil
            showResult = false
        }
    }
}

// MARK: - 阶段枚举

enum CastingPhase: Equatable {
    case preparation
    case casting
    case result
}
