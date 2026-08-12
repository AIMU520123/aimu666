import SwiftUI
import Foundation

// MARK: - App状态管理

/// 全局App状态
///
/// 独立抽离自 YiOracleApp.swift，使库目标（SPM 编译）也能引用，
/// 而含 @main 的入口文件可留在 app target 不参与库构建。
@Observable
final class AppState {
    /// 当前选中的标签
    var selectedTab: AppTab = .today

    /// 是否显示引导页
    var showOnboarding: Bool = false

    /// 是否显示付费墙
    var showPaywall: Bool = false

    /// 导航路径
    var navigationPath = NavigationPath()

    /// 已加载的对话历史
    var recentConversations: [Conversation] = []

    /// 初始化App
    func initialize() async {
        // 检查是否首次启动
        let defaults = UserDefaultsManager.shared
        if defaults.isFirstLaunch {
            defaults.markFirstLaunchIfNeeded()
            showOnboarding = true
        }

        // 加载对话历史
        do {
            recentConversations = try DatabaseManager.shared.loadAllConversations()
        } catch {
            print("[AppState] Failed to load conversations: \(error)")
        }

        // 启动本地推理引擎（设备有真实模型时自动启用，否则 Mock 回落）
        await ModelManager.shared.startup()

        // 加载商店商品并恢复购买权益（满足 3.1.1 跨设备恢复）
        await StoreManager.shared.loadProducts()
    }

    /// 完成引导
    func completeOnboarding() {
        withAnimation {
            showOnboarding = false
        }
        UserDefaultsManager.shared.hasCompletedOnboarding = true
    }
}

/// 标签页枚举
enum AppTab: String, CaseIterable {
    case today = "Today"
    case collection = "Collection"
    case settings = "Settings"
}
