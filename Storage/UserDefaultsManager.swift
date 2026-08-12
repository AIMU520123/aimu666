import Foundation

/// UserDefaults 偏好设置管理器
///
/// 管理应用的轻量级偏好设置，包括：
/// - 用户外观偏好（主题）
/// - 通知偏好
/// - 首次启动标记
/// - 语言选择
/// - 购买状态
///
/// 与 DatabaseManager 区分：
/// - DatabaseManager: 存储大量结构化数据（对话、卦象等）
/// - UserDefaultsManager: 存储简单键值对偏好设置
///
/// 设计意图：
/// - 单一职责：只管理偏好设置，不涉及业务数据
/// - 类型安全：使用枚举封装所有Key，避免字符串硬编码
/// - 默认值：所有读取都提供合理的默认值
@Observable
final class UserDefaultsManager {
    static let shared = UserDefaultsManager()

    private let defaults = UserDefaults.standard

    private init() {}

    // MARK: - Key 枚举

    private enum Key: String {
        case hasCompletedOnboarding = "has_completed_onboarding"
        case preferredLanguage = "preferred_language"
        case colorTheme = "color_theme"
        case selectedTheme = "selected_theme"
        case enableHaptics = "enable_haptics"
        case enableSound = "enable_sound"
        case firstLaunchDate = "first_launch_date"
        case appVersion = "app_version"
        case purchaseVerified = "purchase_verified"
        case purchaseDate = "purchase_date"
        case lastBackupDate = "last_backup_date"
        case dailyReflectionReminder = "daily_reflection_reminder"
        case reflectionReminderTime = "reflection_reminder_time"
        case softenDivinationLanguage = "soften_divination_language"
    }

    // MARK: - 公开属性

    /// 是否完成了首次引导流程
    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: Key.hasCompletedOnboarding.rawValue) }
        set {
            defaults.set(newValue, forKey: Key.hasCompletedOnboarding.rawValue)
        }
    }

    /// 首选语言
    var preferredLanguage: String {
        get {
            defaults.string(forKey: Key.preferredLanguage.rawValue) ?? "en"
        }
        set {
            defaults.set(newValue, forKey: Key.preferredLanguage.rawValue)
        }
    }

    /// 颜色主题：light / dark / system
    var colorTheme: String {
        get {
            defaults.string(forKey: Key.colorTheme.rawValue) ?? "system"
        }
        set {
            defaults.set(newValue, forKey: Key.colorTheme.rawValue)
        }
    }

    /// 界面风格（皮肤）：fantasy_young / classic_iching / female_fantasy
    /// 默认「中国易经风」，最贴合产品初始调性
    var selectedTheme: AppTheme {
        get {
            guard let raw = defaults.string(forKey: Key.selectedTheme.rawValue),
                  let theme = AppTheme(rawValue: raw) else {
                return .classicIChing
            }
            return theme
        }
        set {
            defaults.set(newValue.rawValue, forKey: Key.selectedTheme.rawValue)
        }
    }

    /// 是否启用触觉反馈
    var enableHaptics: Bool {
        get { defaults.object(forKey: Key.enableHaptics.rawValue) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.enableHaptics.rawValue) }
    }

    /// 是否启用音效
    var enableSound: Bool {
        get { defaults.object(forKey: Key.enableSound.rawValue) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.enableSound.rawValue) }
    }

    /// 首次启动日期
    var firstLaunchDate: Date {
        get {
            defaults.object(forKey: Key.firstLaunchDate.rawValue) as? Date ?? Date()
        }
        set {
            defaults.set(newValue, forKey: Key.firstLaunchDate.rawValue)
        }
    }

    /// App版本号（用于检测更新后的数据迁移）
    var appVersion: String {
        get {
            defaults.string(forKey: Key.appVersion.rawValue) ?? "1.0.0"
        }
        set {
            defaults.set(newValue, forKey: Key.appVersion.rawValue)
        }
    }

    /// 购买状态是否已验证
    var purchaseVerified: Bool {
        get { defaults.bool(forKey: Key.purchaseVerified.rawValue) }
        set { defaults.set(newValue, forKey: Key.purchaseVerified.rawValue) }
    }

    /// 购买日期
    var purchaseDate: Date? {
        get {
            defaults.object(forKey: Key.purchaseDate.rawValue) as? Date
        }
        set {
            defaults.set(newValue, forKey: Key.purchaseDate.rawValue)
        }
    }

    /// 每日反思提醒是否开启
    var dailyReflectionReminder: Bool {
        get { defaults.bool(forKey: Key.dailyReflectionReminder.rawValue) }
        set { defaults.set(newValue, forKey: Key.dailyReflectionReminder.rawValue) }
    }

    /// 每日反思提醒时间（格式: "HH:mm"）
    var reflectionReminderTime: String {
        get {
            defaults.string(forKey: Key.reflectionReminderTime.rawValue) ?? "08:00"
        }
        set {
            defaults.set(newValue, forKey: Key.reflectionReminderTime.rawValue)
        }
    }

    /// 上次备份日期
    var lastBackupDate: Date? {
        get {
            defaults.object(forKey: Key.lastBackupDate.rawValue) as? Date
        }
        set {
            defaults.set(newValue, forKey: Key.lastBackupDate.rawValue)
        }
    }

    /// 4.3(b) 语义弱化开关：开启后界面把占卜措辞替换为更中性的"反思/梳理"措辞，
    /// 应对 Apple 审核口径波动（竞品 Struck 曾多次被拒）。
    var softenDivinationLanguage: Bool {
        get { defaults.object(forKey: Key.softenDivinationLanguage.rawValue) as? Bool ?? false }
        set { defaults.set(newValue, forKey: Key.softenDivinationLanguage.rawValue) }
    }

    // MARK: - 工具方法

    /// 重置所有设置为默认值
    func resetAll() {
        let domain = Bundle.main.bundleIdentifier ?? "com.yioracle.app"
        defaults.removePersistentDomain(forName: domain)
        defaults.synchronize()
    }

    /// 标记首次启动
    func markFirstLaunchIfNeeded() {
        if defaults.object(forKey: Key.firstLaunchDate.rawValue) == nil {
            firstLaunchDate = Date()
            appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        }
    }

    /// 检查是否为首次启动
    var isFirstLaunch: Bool {
        defaults.object(forKey: Key.firstLaunchDate.rawValue) == nil
    }
}
