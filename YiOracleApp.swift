import SwiftUI

/// Yi Oracle App 入口
///
/// 应用采用单窗口模式，使用 NavigationStack 管理导航。
/// 启动时：
/// 1. 初始化本地数据库和服务
/// 2. 加载用户画像
/// 3. 显示 TodayReflectionView 作为主界面
///
/// 架构说明：
/// - 使用 @State 管理全局 AppState
/// - 使用 .environment() 注入服务依赖
/// - TabView 提供3个顶级标签（反思、收藏、设置）
/// - 占卜功能藏在 TodayReflectionView 的次级导航中
@main
struct YiOracleApp: App {
    /// 全局App状态
    @State private var appState = AppState()

    /// 用户画像（从本地数据库加载）
    @State private var userProfile = UserProfile()

    var body: some Scene {
        WindowGroup {
            ZStack {
                // 首次启动显示引导页
                if appState.showOnboarding {
                    OnboardingView(appState: appState, userProfile: $userProfile)
                        .transition(.opacity)
                } else {
                    mainContentView
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.5), value: appState.showOnboarding)
            .environment(\.appTheme, UserDefaultsManager.shared.selectedTheme)
            .environment(appState)
            .task {
                await appState.initialize()
            }
        }
    }

    /// 主内容视图
    private var mainContentView: some View {
        TabView(selection: $appState.selectedTab) {
            // Tab 1: 今日反思（主界面）
            TodayReflectionView(userProfile: $userProfile, selectedTab: $appState.selectedTab)
                .tabItem {
                    Label("Today", systemImage: "sun.max")
                }
                .tag(AppTab.today)

            // Tab 2: 卦象收藏
            CollectionView(userProfile: $userProfile)
                .tabItem {
                    Label("Collection", systemImage: "square.grid.3x3")
                }
                .tag(AppTab.collection)

            // Tab 3: 设置
            SettingsView(userProfile: $userProfile)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(AppTab.settings)
        }
        .tint(UserDefaultsManager.shared.selectedTheme.palette.accent)
        .sheet(isPresented: $appState.showPaywall) {
            PaywallView()
        }
    }
}

// MARK: - 引导页

/// 首次启动引导页
///
/// 向用户介绍App的核心价值：
/// 1. 隐私零上传
/// 2. 易经哲思
/// 3. 个人成长伴侣
struct OnboardingView: View {
    let appState: AppState
    @Binding var userProfile: UserProfile

    @State private var currentPage = 0
    @State private var nameInput = ""

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "Welcome to Yi Oracle",
            subtitle: "A quiet space for daily reflection, guided by ancient wisdom",
            icon: "sparkles",
            description: "I'm Yi — not a fortune teller, but a companion who draws from the 3,000-year-old Book of Changes to help you see your life with fresh eyes."
        ),
        OnboardingPage(
            title: "A Hexagram Is a Mirror",
            subtitle: "Not a prediction — a way to see clearly",
            icon: "scope",
            description: "When you cast the coins, you're not predicting the future. You're holding up a mirror to where your heart and mind are right now. The ancient text offers perspective, not fortune-telling. Keep only what resonates."
        ),
        OnboardingPage(
            title: "Your Privacy Matters",
            subtitle: "Everything stays between you and your device",
            icon: "lock.shield",
            description: "No accounts. No servers. No data uploads. Every conversation, every reflection, every hexagram — it all lives here, on your phone, and nowhere else."
        ),
        OnboardingPage(
            title: "What Should I Call You?",
            subtitle: "I'd love to know your name",
            icon: "person.text.rectangle",
            description: "You can share as much or as little as you like. I'll adapt to your style — philosophical, practical, or poetic."
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // 跳过按钮
            HStack {
                Spacer()
                Button("Skip") {
                    appState.completeOnboarding()
                }
                .padding()
                .foregroundStyle(.secondary)
            }

            // 页面内容
            TabView(selection: $currentPage) {
                ForEach(pages.indices, id: \.self) { index in
                    OnboardingPageView(
                        page: pages[index],
                        currentPage: index,
                        nameInput: $nameInput,
                        isLastPage: index == pages.count - 1
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            // 底部按钮
            VStack(spacing: 12) {
                Button {
                    if currentPage < pages.count - 1 {
                        withAnimation { currentPage += 1 }
                    } else {
                        if !nameInput.isEmpty {
                            userProfile.displayName = nameInput
                        }
                        appState.completeOnboarding()
                    }
                } label: {
                    Text(currentPage < pages.count - 1 ? "Continue" : "Begin My Journey")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color("YiInk"))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 40)
        }
        .background(Color("YiBackground"))
    }
}

/// 引导页数据模型
struct OnboardingPage {
    let title: String
    let subtitle: String
    let icon: String
    let description: String
}

/// 引导页单页视图
struct OnboardingPageView: View {
    let page: OnboardingPage
    let currentPage: Int
    @Binding var nameInput: String
    let isLastPage: Bool

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: page.icon)
                .font(.system(size: 64))
                .foregroundColor(Color("YiInk"))
                .padding(.bottom, 16)

            Text(page.title)
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text(page.subtitle)
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Text(page.description)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .lineSpacing(4)

            if isLastPage {
                TextField("Your name (optional)", text: $nameInput)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 32)
                    .padding(.top, 16)
            }

            Spacer()
        }
        .padding()
    }
}
