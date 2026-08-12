import Foundation

/// 预生成模板池服务 — 今日反思内容源
///
/// 为 TodayReflectionView 提供每日反思内容。
/// 使用预生成的模板池可以：
/// 1. 避免每次启动都调用LLM（省电省时）
/// 2. 确保离线可用，零依赖
/// 3. 定期刷新（每日/每周），保持内容新鲜
/// 4. 模板池可根据用户画像做个性化匹配
///
/// 设计意图：
/// - 模板分5大类别：每日开端/自我探索/关系反思/勇气修炼/感恩丰盛
/// - 每个模板关联1-3个卦象
/// - 模板匹配优先级：用户活跃主题 > 今日卦象推荐 > 随机
/// - 支持中英文双语
///
/// 数据来源：
/// - 主池 `reflection_templates_pool.json`（2000 条，Bundle 内），由脚本确定性生成：
///   以 64 卦手工撰写的高质量块（quick/full/deep × practical/philosophical）为基底，
///   叠加基于易学结构（6 爻位原型 + 4 生活域）的扩展，质量对齐端侧 3B 模型产出。
/// - 若 Bundle 缺失该文件（如未加入 target），回退到 `fallbackTemplates`（13 条内联）。
///
/// 模板来源：
/// - 易经卦辞的现代诠释
/// - 结合心理学和正念的反思引导
/// - Yi的温暖人格风格
@Observable
final class TemplatePoolService {
    static let shared = TemplatePoolService()

    /// 模板池
    private(set) var templates: [ReflectionTemplate] = []

    /// 上次刷新时间
    private(set) var lastRefreshDate: Date?

    /// 今日已选模板
    private(set) var todayTemplate: ReflectionTemplate?

    private let matcher = HexagramMatcher.shared
    private let conceptStore = ConceptMappingStore.shared

    private init() {
        loadTemplates()
    }

    // MARK: - 公开接口

    /// 获取今日反思模板
    ///
    /// 匹配策略：
    /// 1. 如果今日已有缓存且未过午夜，返回缓存的模板
    /// 2. 否则，根据用户画像和日期重新匹配模板
    ///
    /// - Parameter userProfile: 用户画像
    /// - Returns: 今日最佳匹配的反思模板
    func getTodayTemplate(for userProfile: UserProfile) -> ReflectionTemplate {
        // 检查缓存
        if let cached = todayTemplate,
           let lastRefresh = lastRefreshDate,
           Calendar.current.isDate(lastRefresh, inSameDayAs: Date()) {
            return cached
        }

        // 重新匹配
        let template = matchTemplate(for: userProfile)
        todayTemplate = template
        lastRefreshDate = Date()
        return template
    }

    /// 刷新模板池
    func refreshTemplates() {
        loadTemplates()
        todayTemplate = nil
        lastRefreshDate = nil
    }

    // MARK: - 模板匹配

    private func matchTemplate(for profile: UserProfile) -> ReflectionTemplate {
        // 1. 获取今日推荐卦象
        let todayHex = matcher.recommendTodayHexagram(for: profile, date: Date())

        // 2. 按用户活跃主题筛选模板
        var scoredTemplates: [(template: ReflectionTemplate, score: Int)] = []

        for template in templates {
            var score = 0

            // 卦象匹配加分
            if template.relatedHexagramIDs.contains(todayHex.id) {
                score += 3
            }

            // 主题匹配加分
            for theme in profile.activeThemes {
                if template.category.rawValue.lowercased().contains(theme.lowercased()) ||
                   theme.lowercased().contains(template.category.rawValue.lowercased()) {
                    score += 2
                }
            }

            // 卦象关键词匹配
            for keyword in todayHex.keywords {
                if template.content.lowercased().contains(keyword) {
                    score += 1
                }
            }

            // 偏好风格加分
            if template.style == profile.castingStyle {
                score += 1
            }

            scoredTemplates.append((template, score))
        }

        // 排序取最高分
        scoredTemplates.sort { $0.score > $1.score }

        // 返回最高分模板或随机模板
        return scoredTemplates.first?.template ?? templates.randomElement()!
    }

    // MARK: - 模板加载

    /// 从 Bundle 加载 2000 条主池；失败时回退到内联最小集。
    private func loadTemplates() {
        if let url = Bundle.main.url(forResource: "reflection_templates_pool", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([ReflectionTemplate].self, from: data),
           !decoded.isEmpty {
            templates = decoded
        } else {
            templates = Self.fallbackTemplates
        }
    }

    // MARK: - 内联回退（仅当 Bundle 缺失 JSON 时启用）

    private static let fallbackTemplates: [ReflectionTemplate] = [
        ReflectionTemplate(
            id: 1,
            category: .dailyStart,
            title: "A New Beginning",
            content: "Today is unwritten, like the blank space before the first brushstroke. Hexagram 24 — Return — reminds us that every sunrise is a miniature rebirth. What seed would you like to plant in the soil of today?",
            relatedHexagramIDs: [24, 3, 1],
            style: .philosophical,
            reflectionQuestion: "What intention do you want to carry with you today?"
        ),
        ReflectionTemplate(
            id: 2,
            category: .dailyStart,
            title: "Gentle Persistence",
            content: "Great rivers don't rush, yet they reach the sea. The wisdom of Hexagram 5 — Waiting — teaches us that patience isn't passive — it's a form of quiet strength. What in your life is worth waiting for?",
            relatedHexagramIDs: [5, 53, 32],
            style: .poetic,
            reflectionQuestion: "Where in your life is patience asking to be your teacher?"
        ),
        ReflectionTemplate(
            id: 4,
            category: .selfDiscovery,
            title: "The Mirror of Thunder",
            content: "When thunder shakes the sky, it doesn't destroy — it awakens. Hexagram 51 speaks of startlement that clarifies. What truth has been rumbling beneath the surface of your awareness, asking to be acknowledged?",
            relatedHexagramIDs: [51, 25, 61],
            style: .poetic,
            reflectionQuestion: "What truth have you been avoiding that now wants to be heard?"
        ),
        ReflectionTemplate(
            id: 7,
            category: .relationships,
            title: "The Gentle Pull",
            content: "Hexagram 31 — Influence — describes the subtle attraction between hearts, like a lake resting on a mountain. True connection doesn't demand; it invites. How have you been invited lately — and how have you invited others?",
            relatedHexagramIDs: [31, 37, 8],
            style: .poetic,
            reflectionQuestion: "Who in your life deserves a moment of your undivided presence today?"
        ),
        ReflectionTemplate(
            id: 10,
            category: .courage,
            title: "The Tiger's Tail",
            content: "Hexagram 10 — Treading — offers one of the I Ching's most vivid images: walking on the tiger's tail. The teaching? 'It does not bite.' Sometimes our fears are tigers that, when approached with awareness, never actually strike. What tiger have you been avoiding?",
            relatedHexagramIDs: [10, 51, 34],
            style: .practical,
            reflectionQuestion: "What fear is actually smaller than it appears when you turn to face it?"
        ),
        ReflectionTemplate(
            id: 13,
            category: .gratitude,
            title: "Abundance All Around",
            content: "Hexagram 14 — Great Possession — carries the image of fire shining from heaven. Its teaching isn't about material wealth but about recognizing how much you already have. True abundance is the capacity to see it. What abundance surrounds you right now that you've been taking for granted?",
            relatedHexagramIDs: [14, 55, 42],
            style: .default,
            reflectionQuestion: "What three things are you genuinely grateful for in this moment?"
        ),
    ]
}

// MARK: - 反思模板模型

/// 反思模板
struct ReflectionTemplate: Identifiable, Codable {
    let id: Int
    let category: TemplateCategory
    let title: String
    let content: String
    let relatedHexagramIDs: [Int]
    let style: CastingStyle
    let reflectionQuestion: String
}

/// 模板分类
enum TemplateCategory: String, Codable, CaseIterable {
    case dailyStart = "Daily Start"
    case selfDiscovery = "Self Discovery"
    case relationships = "Relationships"
    case courage = "Courage"
    case gratitude = "Gratitude"

    var icon: String {
        switch self {
        case .dailyStart: return "sunrise"
        case .selfDiscovery: return "figure.mind.and.body"
        case .relationships: return "heart"
        case .courage: return "flame"
        case .gratitude: return "hands.sparkles"
        }
    }
}
