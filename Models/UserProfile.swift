import Foundation

/// 用户画像模型 — Yi的记忆核心
///
/// 存储用户的个性特征、反思偏好、历史交互模式，
/// 用于让Yi（AI Agent）根据不同用户风格因材施教。
///
/// 所有数据本地存储，绝不上传。
@Observable
final class UserProfile: Codable {
    /// 用户选择的称呼名
    var displayName: String

    /// 用户简介（可选，由用户自行填写）
    var bio: String

    /// 当前语言偏好
    var preferredLanguage: Language

    /// 当前的反思/生活主题标签
    var activeThemes: [String]

    /// 已解锁的卦象ID集合
    var unlockedHexagramIDs: Set<Int>

    /// 最常出现的卦象ID（用于个性化推荐）
    var frequentHexagramIDs: [Int]

    /// 交互总次数
    var totalInteractions: Int

    /// 今日已交互次数
    var todayInteractions: Int

    /// 上次活跃日期
    var lastActiveDate: Date

    /// 上次完成反思的日期（用于连续打卡 streak 计算）
    var lastReflectionDate: Date?

    /// 连续反思天数（打卡火焰）
    var streakDays: Int

    /// 累计反思次数（免费价值闭环的核心指标）
    var reflectionCountTotal: Int

    /// 累计起卦次数（免费额度计量：前 freeCastAllowance 次免费，之后引导买断/微交易）
    var castsUsedTotal: Int

    /// 免费起卦额度（体验用，耗尽后引导买断）
    static let freeCastAllowance = 3

    /// 创建日期
    var createdAt: Date

    /// Yi对该用户的认知摘要（由AI生成，非硬编码）
    var yiMemoryNote: String

    /// 用户选择的占卜风格偏好
    var castingStyle: CastingStyle

    /// 用户焦虑/压力等级（1-5，用于温和交互调整）
    var stressLevel: Int

    /// 是否为新用户
    var isNewUser: Bool

    /// 今日是否已进行过日省反思
    var hasDoneTodayReflection: Bool {
        guard let last = lastReflectionDate else { return false }
        return Calendar.current.isDate(last, inSameDayAs: Date())
    }

    /// 记录一次完成的反思，更新连续打卡与累计计数
    ///
    /// 规则：
    /// - 今日已记录：计数不变，仅刷新时间戳
    /// - 与上次记录相隔一天（含今天首次）：streak + 1
    /// - 中断超过一天：streak 重置为 1
    /// 返回更新后的 streakDays
    @discardableResult
    mutating func recordReflection() -> Int {
        reflectionCountTotal += 1
        lastActiveDate = Date()

        guard let last = lastReflectionDate else {
            streakDays = 1
            lastReflectionDate = Date()
            return streakDays
        }

        if Calendar.current.isDate(last, inSameDayAs: Date()) {
            lastReflectionDate = Date()
            return streakDays
        }

        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        if Calendar.current.isDate(last, inSameDayAs: yesterday) {
            streakDays += 1
        } else {
            streakDays = 1
        }
        lastReflectionDate = Date()
        return streakDays
    }

    /// 解锁进度百分比
    var collectionProgress: Double {
        Double(unlockedHexagramIDs.count) / 64.0
    }

    init(
        displayName: String = "",
        bio: String = "",
        preferredLanguage: Language = .english,
        activeThemes: [String] = [],
        unlockedHexagramIDs: Set<Int> = [1],  // 默认解锁乾卦
        frequentHexagramIDs: [Int] = [],
        totalInteractions: Int = 0,
        todayInteractions: Int = 0,
        lastActiveDate: Date = Date(),
        lastReflectionDate: Date? = nil,
        streakDays: Int = 0,
        reflectionCountTotal: Int = 0,
        castsUsedTotal: Int = 0,
        createdAt: Date = Date(),
        yiMemoryNote: String = "",
        castingStyle: CastingStyle = .default,
        stressLevel: Int = 1,
        isNewUser: Bool = true
    ) {
        self.displayName = displayName
        self.bio = bio
        self.preferredLanguage = preferredLanguage
        self.activeThemes = activeThemes
        self.unlockedHexagramIDs = unlockedHexagramIDs
        self.frequentHexagramIDs = frequentHexagramIDs
        self.totalInteractions = totalInteractions
        self.todayInteractions = todayInteractions
        self.lastActiveDate = lastActiveDate
        self.lastReflectionDate = lastReflectionDate
        self.streakDays = streakDays
        self.reflectionCountTotal = reflectionCountTotal
        self.castsUsedTotal = castsUsedTotal
        self.createdAt = createdAt
        self.yiMemoryNote = yiMemoryNote
        self.castingStyle = castingStyle
        self.stressLevel = stressLevel
        self.isNewUser = isNewUser
    }
}

// MARK: - 相关枚举

/// 支持的语言
enum Language: String, Codable, CaseIterable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case japanese = "ja"
    case korean = "ko"

    var displayName: String {
        switch self {
        case .english: return "English"
        case .simplifiedChinese: return "简体中文"
        case .traditionalChinese: return "繁體中文"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        }
    }
}

/// 占卜风格偏好
enum CastingStyle: String, Codable, CaseIterable {
    case `default` = "Classic"
    case philosophical = "Philosophical"
    case practical = "Practical"
    case poetic = "Poetic"

    var description: String {
        switch self {
        case .default: return "Classic — balanced and traditional"
        case .philosophical: return "Philosophical — deep reflections"
        case .practical: return "Practical — actionable advice"
        case .poetic: return "Poetic — lyrical and metaphorical"
        }
    }
}
