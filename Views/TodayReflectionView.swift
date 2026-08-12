import SwiftUI
import StoreKit
import UIKit

/// 今日反思主界面 — Yi Oracle 的核心页
///
/// 设计理念：
/// - 不展示"占卜"标签 — 这是"反思"而非"预测"的App
/// - 三套可切换皮肤（中国玄幻 / 中国易经 / 女性玄幻）通过 `theme.palette` 驱动
/// - 卦象卡片作为视觉焦点但不强调神秘感
/// - Yi的反思建议使用温暖、引导性的语言
///
/// Apple 4.3(b) 规避策略：
/// - 不做"今日运势""每日占卜"等表述
/// - 卦象展示强调其哲理含义，非预测功能
/// - 核心CTA是"Talk to Yi"（对话），而非"Cast"(占卜)
struct TodayReflectionView: View {
    @Binding var userProfile: UserProfile
    @Binding var selectedTab: AppTab

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.appTheme) var theme

    @State private var todayTemplate: ReflectionTemplate?
    @State private var todayHexagram: Hexagram?
    @State private var showChatSheet = false
    @State private var showCastingSheet = false
    @State private var showMoreOptions = false
    @State private var hasCompletedTodayReflection = false
    @State private var isAnimating = false
    @State private var shareImage: IdentifiableImage?
    @State private var selectedSkin: ReflectionCardSkin = .ink

    private let templateService = TemplatePoolService.shared
    private let matcher = HexagramMatcher.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // 顶部日期和问候
                    headerView
                        .padding(.top, 16)

                    // 卦象卡片
                    hexagramCardView
                        .padding(.top, 20)

                    // Yi的反思建议
                    reflectionSection
                        .padding(.top, 28)

                    // 快速操作入口
                    quickActionsView
                        .padding(.top, 32)
                        .padding(.bottom, 40)
                }
                .padding(.horizontal, 20)
            }
            .background(theme.palette.backgroundGradient)
            .navigationBarHidden(true)
            .sheet(isPresented: $showChatSheet) {
                ChatView(userProfile: $userProfile)
            }
            .sheet(isPresented: $showCastingSheet) {
                CastingView(userProfile: $userProfile)
            }
            .sheet(item: $shareImage) { item in
                ShareSheet(activityItems: [item.image])
            }
            .task {
                await loadTodayContent()
            }
            .onAppear {
                // 同步已持久化的反思完成状态
                hasCompletedTodayReflection = userProfile.hasDoneTodayReflection
                withAnimation(.easeInOut(duration: 1.0)) {
                    isAnimating = true
                }
            }
        }
    }

    // MARK: - 子视图

    /// 顶部日期和问候
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(formattedDate)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text(greetingText)
                        .font(.largeTitle)
                        .fontWeight(.medium)
                        .foregroundColor(theme.palette.ink)

                    // 连续打卡火苗（留存正反馈）
                    if userProfile.streakDays > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.caption)
                                .foregroundColor(theme.palette.accent)
                            Text("\(userProfile.streakDays)-day streak")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 2)
                    }
                }

                Spacer()

                // 更多选项按钮
                Button {
                    showMoreOptions.toggle()
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundColor(theme.palette.ink.opacity(0.6))
                }
                .confirmationDialog("Explore", isPresented: $showMoreOptions) {
                    Button(UserDefaultsManager.shared.softenDivinationLanguage ? "Reflect with the coins" : "Cast the Coins") { showCastingSheet = true }
                    Button("Browse Your Collection") { selectedTab = .collection }
                    Button("Talk to Yi") { showChatSheet = true }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("What would you like to explore?")
                }
            }
        }
    }

    /// 卦象卡片
    private var hexagramCardView: some View {
        NavigationLink {
            if let hex = todayHexagram {
                HexagramDetailView(hexagram: hex, userProfile: $userProfile)
            }
        } label: {
            VStack(spacing: 12) {
                // 卦象符号
                if let hex = todayHexagram {
                    Text(hex.symbol)
                        .font(.system(size: 72))
                        .foregroundColor(theme.palette.ink)
                        .opacity(isAnimating ? 1 : 0)
                        .scaleEffect(isAnimating ? 1 : 0.8)

                    // 卦象名称
                    Text(hex.nameEN)
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(theme.palette.ink)

                    // 核心含义
                    Text(hex.coreMeaning)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.horizontal, 12)

                    // 爻线可视化
                    HexagramLinesView(lines: hex.lines, color: theme.palette.ink)
                        .frame(height: 80)
                        .padding(.top, 4)
                } else {
                    ProgressView()
                        .scaleEffect(1.2)
                        .padding()
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(theme.palette.cardBackground)
                    .shadow(color: theme.palette.shadow, radius: 10, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(theme.palette.cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 20)
    }

    /// Yi的反思建议
    private var reflectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.subheadline)
                    .foregroundColor(theme.palette.ink.opacity(0.6))
                Text("Yi's Reflection")
                    .font(.headline)
                    .foregroundColor(theme.palette.ink)
            }

            if let template = todayTemplate {
                // 反思内容卡片
                VStack(alignment: .leading, spacing: 16) {
                    Text(template.title)
                        .font(.title3)
                        .fontWeight(.semibold)

                    // 今日之时：把卦象翻译成「当下阶段」的反思叙事（非预测），强化 Yi 人格与易经「时」的哲学
                    if let hex = todayHexagram {
                        let phase = YiPersona.insight(forHexagramID: hex.id).phase
                        Text("Right now, \(hex.nameEN) invites you to \(phase).")
                            .font(.subheadline)
                            .foregroundColor(theme.palette.accent)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Text(template.content)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)

                    Divider()
                        .background(theme.palette.cardBorder)

                    // 反思引导问题
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Take a moment to reflect...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text(template.reflectionQuestion)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(theme.palette.ink)
                    }

                    // 反思完成按钮
                    Button {
                        withAnimation {
                            if !hasCompletedTodayReflection {
                                // 落库：连续打卡 + 累计计数
                                _ = userProfile.recordReflection()
                                try? DatabaseManager.shared.saveUserProfile(userProfile)
                                hasCompletedTodayReflection = true

                                // 每完成 3 次反思请求 App Store 评分，养 ASO
                                if userProfile.reflectionCountTotal % 3 == 0 {
                                    if let scene = UIApplication.shared.connectedScenes
                                        .first(where: { $0 is UIWindowScene }) as? UIWindowScene {
                                        SKStoreReviewController.requestReview(in: scene)
                                    }
                                }
                            } else {
                                hasCompletedTodayReflection = false
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: hasCompletedTodayReflection ?
                                  "checkmark.circle.fill" : "circle")
                                .font(.title3)
                            Text(hasCompletedTodayReflection ?
                                 "Reflected for today" : "I've reflected on this")
                                .font(.subheadline)
                        }
                        .foregroundColor(hasCompletedTodayReflection ?
                                         theme.palette.ink : .secondary)
                    }
                    .buttonStyle(.plain)

                    // 分享卡皮肤选择（墨/金/玉，离线确定配色，提升社媒观感）
                    HStack(spacing: 12) {
                        Text("Card style")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        ForEach(ReflectionCardSkin.allCases) { skin in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedSkin = skin
                                }
                            } label: {
                                Circle()
                                    .fill(skin.swatch)
                                    .frame(width: 22, height: 22)
                                    .overlay(
                                        Circle()
                                            .stroke(selectedSkin == skin ?
                                                    theme.palette.ink : .clear, lineWidth: 2)
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(.white, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // 分享反思卡（离线渲染，出设备仅静态图，符合隐私定位）
                    Button {
                        renderAndShare()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title3)
                            Text("Share this card")
                                .font(.subheadline)
                        }
                        .foregroundColor(theme.palette.accent)
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(theme.palette.cardBackground)
                )
            } else {
                HStack {
                    Spacer()
                    ProgressView("Searching for today's wisdom...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(40)
            }
        }
    }

    /// 快速操作入口
    private var quickActionsView: some View {
        VStack(spacing: 12) {
            // 主要操作：与Yi对话
            Button {
                showChatSheet = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.title3)
                    Text("Talk to Yi")
                        .fontWeight(.semibold)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.subheadline)
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(theme.palette.accent)
                )
                .foregroundColor(theme.palette.textOnAccent)
            }

            // 次要操作：浏览收藏
            NavigationLink {
                CollectionView(userProfile: $userProfile)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "square.grid.3x3")
                        .font(.title3)
                    Text("Browse Your Collection")
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(userProfile.unlockedHexagramIDs.count)/64")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(theme.palette.ink.opacity(0.15), lineWidth: 1)
                )
                .foregroundColor(theme.palette.ink)
            }

            // 次级操作：起卦（温和 CTA，平衡 4.3(b) 防御与用户对"算一卦"的真实欲望）
            Button {
                showCastingSheet = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "die.face.3")
                        .font(.title3)
                    Text(UserDefaultsManager.shared.softenDivinationLanguage ? "Reflect with the coins" : "Cast the Coins")
                        .fontWeight(.medium)
                    if userProfile.castsUsedTotal < UserProfile.freeCastAllowance {
                        Text("Free")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(theme.palette.accentSoft))
                            .foregroundColor(theme.palette.accent)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(theme.palette.ink.opacity(0.15), lineWidth: 1)
                )
                .foregroundColor(theme.palette.ink)
            }
        }
    }

    // MARK: - 辅助

    /// 格式化日期
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date())
    }

    /// 问候语
    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let name = userProfile.displayName.isEmpty ? "" : ", \(userProfile.displayName)"

        switch hour {
        case 0..<12: return "Good morning\(name)"
        case 12..<18: return "Good afternoon\(name)"
        default: return "Good evening\(name)"
        }
    }

    /// 加载今日内容
    private func loadTodayContent() async {
        todayHexagram = matcher.recommendTodayHexagram(for: userProfile)
        todayTemplate = templateService.getTodayTemplate(for: userProfile)
    }

    /// 离线渲染反思卡为图片并唤起系统分享（数据不出设备）
    private func renderAndShare() {
        guard let hex = todayHexagram, let tpl = todayTemplate else { return }
        let signature = YiPersona.insight(forHexagramID: hex.id).signature
        let card = ReflectionCard(hexagram: hex, template: tpl, skin: selectedSkin, signature: signature)
        let renderer = ImageRenderer(content: card)
        renderer.scale = UIScreen.main.scale
        if let uiImage = renderer.uiImage {
            shareImage = IdentifiableImage(image: uiImage)
        }
    }
}

// MARK: - 卦象线条视图

/// 卦象六爻线条渲染组件
///
/// 以主题墨色渲染卦象的六行爻：
/// - 阳爻为一条实线
/// - 阴爻为中间断开的双线
/// - 从下往上排列（初爻在底部）
struct HexagramLinesView: View {
    let lines: [Bool]
    let color: Color

    var body: some View {
        VStack(spacing: 0) {
            ForEach(lines.indices.reversed(), id: \.self) { index in
                if lines[index] {
                    // 阳爻 — 实线
                    Rectangle()
                        .fill(color)
                        .frame(height: 4)
                        .frame(maxWidth: 200)
                        .padding(.vertical, 6)
                } else {
                    // 阴爻 — 断线
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(color)
                            .frame(width: 90, height: 4)
                        Spacer()
                            .frame(width: 20)
                        Rectangle()
                            .fill(color)
                            .frame(width: 90, height: 4)
                    }
                    .frame(maxWidth: 200)
                    .padding(.vertical, 6)
                }
            }
        }
    }
}
