import SwiftUI
import UIKit

/// 卦象详情页
///
/// 展示单个卦象的完整信息：
/// - 卦象符号（Unicode字符）
/// - 六爻线条水墨渲染
/// - 中英文卦名
/// - 核心含义
/// - 卦辞原文与英译
/// - 大象辞
/// - 关键概念分析
/// - 解锁状态/解锁操作
///
/// 设计意图：
/// - 营造 "翻阅古籍" 的平静阅读体验
/// - 避免过度设计 — 简洁、优雅、聚焦内容
/// - 黑色/灰色为主色调（水墨风格）
struct HexagramDetailView: View {
    let hexagram: Hexagram
    @Binding var userProfile: UserProfile

    @Environment(\.dismiss) var dismiss
    @Environment(\.appTheme) var theme
    @Environment(AppState.self) var appState

    @State private var showFullJudgement = false
    @State private var isUnlocked: Bool

    /// 深度解读：买断用户直接进入锚定对话；非买断用户触发付费墙
    @State private var deepReadingCasting: CastingResult? = nil

    /// 分享卡导出
    @State private var shareImage: UIImage? = nil
    @State private var showShareSheet = false
    @State private var selectedShareSkin: ReflectionCardSkin = .ink

    private let store = StoreManager.shared
    private let matcher = HexagramMatcher.shared

    init(hexagram: Hexagram, userProfile: Binding<UserProfile>) {
        self.hexagram = hexagram
        self._userProfile = userProfile
        self._isUnlocked = State(initialValue: hexagram.isUnlocked ||
                                 userProfile.wrappedValue.unlockedHexagramIDs.contains(hexagram.id))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 卦象符号 + 名称
                hexagramHeader
                    .padding(.top, 8)

                // 解锁状态
                if !isUnlocked {
                    unlockBanner
                }

                // 六爻线条渲染
                HexagramLinesView(lines: hexagram.lines, color: theme.palette.ink)
                    .frame(height: 100)
                    .padding(.vertical, 4)

                // 基本信息卡片
                basicInfoCard

                // 核心含义
                coreMeaningSection

                // 今日之时：把卦象翻译成「当下阶段」的反思叙事（非预测），与今日反思主界面一致
                yiMomentSection

                // 卦辞
                judgementSection

                // 大象辞
                imageSection

                // 六爻爻辞（真经文）
                linesSection

                // 关键概念
                keywordsSection

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
        }
        .background(theme.palette.backgroundGradient)
        .navigationTitle("Hexagram \(hexagram.id)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    // 深度解读（付费围墙入口）
                    Button {
                        if store.isPremium {
                            deepReadingCasting = CastingResult(
                                tossResults: [],
                                generatedLines: hexagram.lines,
                                changingLineIndices: [],
                                primaryHexagramID: hexagram.id,
                                transformedHexagramID: nil,
                                nuclearHexagramID: matcher.nuclearHexagram(from: hexagram.lines)?.id ?? hexagram.id,
                                userQuestion: "Offer a deeper, layered reading of this hexagram.",
                                isSaved: isUnlocked
                            )
                        } else {
                            appState.showPaywall = true
                        }
                    } label: {
                        Image(systemName: "text.book.closed")
                            .foregroundColor(theme.palette.ink)
                    }

                    // 分享（借 Co-Star 式裂变补 Referral 缺口），含三套皮肤选择
                    Menu {
                        ForEach(ReflectionCardSkin.allCases) { skin in
                            Button {
                                shareWithSkin(skin)
                            } label: {
                                Label(skin.displayName,
                                      systemImage: selectedShareSkin == skin ? "checkmark.circle.fill" : "circle")
                            }
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(theme.palette.ink)
                    }
                }
            }
        }
        .sheet(item: $deepReadingCasting) { cr in
            ChatView(userProfile: $userProfile, initialCasting: cr)
        }
        .sheet(isPresented: $showShareSheet) {
            if let image = shareImage {
                ShareSheet(activityItems: [image])
            }
        }
    }

    // MARK: - 子视图

    private var hexagramHeader: some View {
        VStack(spacing: 8) {
            Text(hexagram.symbol)
                .font(.system(size: 80))
                .foregroundColor(theme.palette.ink)

            Text(hexagram.nameEN)
                .font(.title)
                .fontWeight(.semibold)
                .foregroundColor(theme.palette.ink)

            Text(hexagram.nameCN)
                .font(.title2)
                .foregroundColor(.secondary)

            Text(hexagram.namePinyin)
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .padding(.vertical, 12)
    }

    private var unlockBanner: some View {
        Button {
            unlockHexagram()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "lock.open")
                Text("Unlock through reflection or casting")
                    .font(.subheadline)
            }
            .foregroundColor(theme.palette.ink)
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(theme.palette.ink.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var basicInfoCard: some View {
        HStack(spacing: 16) {
            infoBadge(label: "Upper", value: hexagram.upperTrigram)
            infoBadge(label: "Lower", value: hexagram.lowerTrigram)
            infoBadge(label: "Element", value: hexagram.element)
            infoBadge(label: "Lines", value: "\(hexagram.yangCount)Y/\(hexagram.yinCount)y")
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
        )
    }

    private func infoBadge(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(theme.palette.ink)
        }
        .frame(maxWidth: .infinity)
    }

    private var coreMeaningSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Core Meaning")

            Text(hexagram.coreMeaning)
                .font(.body)
                .foregroundColor(.primary)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(theme.palette.ink.opacity(0.04))
                )
        }
    }

    /// Yi 的当下映照：用 YiPersona 的 phase 文案，把卦象译成「此刻阶段」而非预测，
    /// 既强化人格一致性，也稳过 App Store 对算命类 App 的审查。
    private var yiMomentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Yi's Mirror")

            let phase = YiPersona.insight(forHexagramID: hexagram.id).phase
            Text("Right now, \(hexagram.nameEN) invites you to \(phase).")
                .font(.body)
                .foregroundColor(theme.palette.accent)
                .italic()
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(theme.palette.accent.opacity(0.06))
                )
        }
    }

    private var judgementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("The Judgement")

            VStack(alignment: .leading, spacing: 8) {
                Text(hexagram.judgementCN)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(theme.palette.ink)

                Divider()
                    .background(theme.palette.ink.opacity(0.1))

                Text(hexagram.judgementEN)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .italic()
                    .lineSpacing(4)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(theme.palette.ink.opacity(0.12), lineWidth: 1)
            )
        }
    }

    private var imageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("The Image")

            VStack(alignment: .leading, spacing: 8) {
                Text(hexagram.imageCN)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(theme.palette.ink)

                Divider()
                    .background(theme.palette.ink.opacity(0.1))

                Text(hexagram.imageEN)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .italic()
                    .lineSpacing(4)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(theme.palette.ink.opacity(0.12), lineWidth: 1)
            )
        }
    }

    private var linesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("The Lines (Yao Ci)")

            if hexagram.lineTexts.isEmpty {
                Text("Line texts are not available in this build.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array(hexagram.lineTexts.enumerated()), id: \.offset) { index, text in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Line \(index + 1)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(theme.palette.ink)

                        Text(text)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .italic()
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(theme.palette.ink.opacity(0.03))
                    )
                }
            }
        }
    }

    private var keywordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Associated Themes")

            FlowLayout(spacing: 8) {
                ForEach(hexagram.keywords, id: \.self) { keyword in
                    Text(keyword.capitalized)
                        .font(.subheadline)
                        .foregroundColor(theme.palette.ink)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(theme.palette.ink.opacity(0.08))
                        )
                }
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(.secondary)
            .textCase(.uppercase)
            .tracking(1)
    }

    // MARK: - 操作

    private func unlockHexagram() {
        isUnlocked = true
        userProfile.unlockedHexagramIDs.insert(hexagram.id)
        do {
            try DatabaseManager.shared.unlockHexagram(
                id: hexagram.id, method: "manual_unlock"
            )
        } catch {
            print("Failed to unlock: \(error)")
        }
    }

    /// 离线渲染竖版分享卡为图片并唤起系统分享（数据不出设备）。皮肤由用户从菜单选定。
    private func shareWithSkin(_ skin: ReflectionCardSkin) {
        selectedShareSkin = skin
        let renderer = ImageRenderer(content: HexagramShareCard(hexagram: hexagram, skin: skin))
        renderer.proposedSize = .init(width: 1080, height: 1350)
        if let image = renderer.uiImage {
            shareImage = image
            showShareSheet = true
        }
    }
}

// MARK: - 分享卡与分享出口

/// 可导出为图片的卦象分享卡（定位"分享你的反思"，非"算命结果"）
/// 支持三套皮肤（墨/金/玉），与今日反思页的 ReflectionCard 视觉系统一致。
struct HexagramShareCard: View {
    let hexagram: Hexagram
    let skin: ReflectionCardSkin

    var body: some View {
        VStack(spacing: 24) {
            Text(hexagram.symbol)
                .font(.system(size: 160))
                .foregroundColor(skin.ink)

            Text(hexagram.nameEN)
                .font(.largeTitle)
                .fontWeight(.semibold)
                .foregroundColor(skin.ink)

            Text(hexagram.nameCN)
                .font(.title2)
                .foregroundColor(skin.textPrimary)

            Text(hexagram.coreMeaning)
                .font(.body)
                .foregroundColor(skin.ink)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 48)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)

            // 今日之时：与详情页 Yi's Mirror、今日反思主界面同源的「当下阶段」叙事（非预测）
            let phase = YiPersona.insight(forHexagramID: hexagram.id).phase
            Text("Right now, \(hexagram.nameEN) invites you to \(phase).")
                .font(.title3)
                .italic()
                .foregroundColor(skin.accent)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 48)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            Text("Yi Oracle — a mirror, not a fortune")
                .font(.caption)
                .foregroundColor(skin.textPrimary)
        }
        .padding(48)
        .frame(width: 1080, height: 1350)
        .background(skin.background)
    }
}

/// UIActivityViewController 封装，用于系统分享面板
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - FlowLayout（关键词瀑布流）

/// 简单的瀑布流布局，用于渲染关键词标签
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for frame in result.frames {
            subviews[frame.index].place(
                at: CGPoint(x: bounds.minX + frame.origin.x, y: bounds.minY + frame.origin.y),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (frames: [LayoutFrame], size: CGSize) {
        var frames: [LayoutFrame] = []
        let maxWidth = proposal.width ?? 300
        var x: CGFloat = 0
        var y: CGFloat = 0
        var currentLineHeight: CGFloat = 0

        for (index, subview) in subviews.enumerated() {
            let subviewSize = subview.sizeThatFits(.unspecified)

            if x + subviewSize.width > maxWidth, x > 0 {
                x = 0
                y += currentLineHeight + spacing
                currentLineHeight = 0
            }

            frames.append(LayoutFrame(
                index: index,
                origin: CGPoint(x: x, y: y),
                size: subviewSize
            ))

            x += subviewSize.width + spacing
            currentLineHeight = max(currentLineHeight, subviewSize.height)
        }

        let totalHeight = y + currentLineHeight
        return (frames, CGSize(width: maxWidth, height: totalHeight))
    }

    struct LayoutFrame {
        let index: Int
        let origin: CGPoint
        let size: CGSize
    }
}
