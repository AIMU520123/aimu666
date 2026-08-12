import Foundation

/// 概念映射表 — 用户问题 → 易经概念的语义匹配数据
///
/// 提供关键词到相关卦象、主题的映射关系，用于：
/// 1. RAG检索的初始锚点 — 当用户提出问题时快速定位相关卦象
/// 2. 每日反思模板匹配 — 根据日期/季节/主题推荐卦象
/// 3. LLM提示增强 — 为本地模型提供上下文锚定
///
/// 数据结构：双层映射
/// - 第一层：情感/语义概念 → 翻译映射
/// - 第二层：具体关键词 → 候选卦象ID列表
///
/// 所有数据硬编码本地，零网络请求。
final class ConceptMappingStore {
    static let shared = ConceptMappingStore()

    // MARK: - 语义 → 卦象映射

    /// 关键词 → 最相关卦象ID列表（按相关度排序）
    private let keywordToHexagrams: [String: [Int]] = [
        // 情绪与心理状态
        "anxiety": [5, 52, 24, 29],           // 需、艮、复、坎
        "stress": [5, 52, 41, 6],             // 需、艮、损、讼
        "peace": [11, 15, 58, 63],            // 泰、谦、兑、既济
        "joy": [16, 58, 55, 14],             // 豫、兑、丰、大有
        "sadness": [36, 47, 23, 29],         // 明夷、困、剥、坎
        "confusion": [4, 3, 20, 59],         // 蒙、屯、观、涣
        "fear": [51, 29, 5, 52],             // 震、坎、需、艮
        "hope": [35, 24, 42, 46],            // 晋、复、益、升
        "grief": [36, 47, 62, 44],           // 明夷、困、小过、姤
        "anger": [6, 21, 38, 43],            // 讼、噬嗑、睽、夬

        // 生活主题
        "career": [45, 35, 46, 7],           // 萃、晋、升、师
        "relationship": [31, 54, 37, 44],    // 咸、归妹、家人、姤
        "family": [37, 8, 13, 42],           // 家人、比、同人、益
        "health": [27, 24, 48, 50],          // 颐、复、井、鼎
        "money": [14, 9, 42, 55],            // 大有、小畜、益、丰
        "decision": [43, 21, 44, 49],        // 夬、噬嗑、姤、革
        "change": [49, 24, 32, 12],          // 革、复、恒、否
        "transition": [63, 64, 53, 49],      // 既济、未济、渐、革
        "growth": [46, 42, 26, 35],          // 升、益、大畜、晋
        "challenge": [39, 29, 3, 47],        // 蹇、坎、屯、困

        // 哲学概念
        "balance": [11, 12, 63, 60],         // 泰、否、既济、节
        "harmony": [11, 15, 37, 61],         // 泰、谦、家人、中孚
        "patience": [5, 53, 9, 32],          // 需、渐、小畜、恒
        "courage": [1, 34, 21, 51],          // 乾、大壮、噬嗑、震
        "wisdom": [26, 4, 50, 48],           // 大畜、蒙、鼎、井
        "sincerity": [61, 25, 8, 45],        // 中孚、无妄、比、萃
        "humility": [15, 33, 41, 62],        // 谦、遁、损、小过
        "perseverance": [1, 32, 7, 46],      // 乾、恒、师、升
    ]

    /// 日期/季节 → 推荐卦象（用于每日反思）
    private let seasonalHexagrams: [String: [Int]] = [
        "spring": [24, 3, 42, 46, 51, 25],   // 复、屯、益、升、震、无妄 — 新生/启动
        "summer": [30, 55, 14, 35, 16, 1],   // 离、丰、大有、晋、豫、乾 — 丰盛/发光
        "autumn": [58, 15, 41, 43, 49, 22],  // 兑、谦、损、夬、革、贲 — 收获/断舍离
        "winter": [29, 52, 5, 26, 36, 2],    // 坎、艮、需、大畜、明夷、坤 — 内省/储藏
        "new_moon": [24, 3, 25, 11],          // 新月 — 新开始
        "full_moon": [55, 14, 63, 58],        // 满月 — 丰盛/完成
    ]

    /// 用户意图前缀 → 关联卦象
    private let intentHexagrams: [String: [Int]] = [
        "why": [4, 20, 50, 48],              // "Why" 问题 → 寻求理解
        "how": [46, 53, 7, 32],              // "How" 问题 → 寻求方法
        "when": [5, 24, 44, 49],             // "When" 问题 → 时机问题
        "what_should": [43, 44, 21, 16],     // "What should I" → 决策问题
        "relationship": [31, 54, 37, 38],    // 关系问题
        "work": [35, 45, 46, 7],             // 工作问题
    ]

    private init() {}

    // MARK: - 公开接口

    /// 根据关键词返回相关卦象ID列表
    func hexagramIDs(for keyword: String) -> [Int] {
        let lower = keyword.lowercased()
        // 精确匹配
        if let ids = keywordToHexagrams[lower] {
            return ids
        }
        // 模糊匹配
        for (key, ids) in keywordToHexagrams {
            if lower.contains(key) || key.contains(lower) {
                return ids
            }
        }
        return []
    }

    /// 检测用户输入中的关键词并返回相关卦象
    func detectHexagrams(from text: String) -> [Int] {
        let words = text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 2 }

        var allIDs: [Int] = []
        for word in words {
            allIDs.append(contentsOf: hexagramIDs(for: word))
        }

        // 去重并保持顺序
        var seen = Set<Int>()
        return allIDs.filter { seen.insert($0).inserted }
    }

    /// 根据当前季节获取推荐卦象
    func seasonalHexagramIDs(for date: Date = Date()) -> [Int] {
        let month = Calendar.current.component(.month, from: date)
        let season: String
        switch month {
        case 3...5: season = "spring"
        case 6...8: season = "summer"
        case 9...11: season = "autumn"
        default: season = "winter"
        }
        return seasonalHexagrams[season] ?? [1, 2]  // 默认返回乾坤二卦
    }

    /// 根据当前月相大致获取推荐卦象
    /// （简化计算，实际应用可使用更精确的月相算法）
    func lunarPhaseHexagramIDs(for date: Date = Date()) -> [Int] {
        let day = Calendar.current.component(.day, from: date)
        if day <= 7 || day >= 25 {
            return seasonalHexagrams["new_moon"] ?? [24]
        } else if day >= 13 && day <= 17 {
            return seasonalHexagrams["full_moon"] ?? [55]
        }
        return seasonalHexagramIDs(for: date)
    }

    /// 获取所有概念关键词
    func allKeywords() -> [String] {
        Array(keywordToHexagrams.keys).sorted()
    }

    /// 根据情感词获取卦象
    func hexagramsForMood(_ mood: String) -> [Int] {
        hexagramIDs(for: mood)
    }
}

// MARK: - 主题分类枚举

/// 反思/对话主题分类
enum ReflectionTheme: String, CaseIterable, Codable {
    case innerPeace = "Inner Peace"
    case personalGrowth = "Personal Growth"
    case relationships = "Relationships"
    case career = "Career & Purpose"
    case creativity = "Creativity"
    case health = "Health & Wellbeing"
    case decision = "Decision Making"
    case transition = "Life Transitions"
    case gratitude = "Gratitude"
    case courage = "Courage"

    /// 关联的卦象ID
    var relatedHexagramIDs: [Int] {
        switch self {
        case .innerPeace: return [11, 52, 24, 58, 15]
        case .personalGrowth: return [1, 26, 46, 4, 50]
        case .relationships: return [31, 37, 8, 44, 54]
        case .career: return [35, 45, 7, 46, 14]
        case .creativity: return [1, 50, 22, 30, 16]
        case .health: return [27, 24, 48, 41, 60]
        case .decision: return [43, 21, 44, 49, 5]
        case .transition: return [49, 24, 63, 64, 53]
        case .gratitude: return [14, 55, 58, 15, 45]
        case .courage: return [1, 51, 34, 21, 43]
        }
    }

    /// 主题对应的提示引导问题
    var reflectionPrompt: String {
        switch self {
        case .innerPeace:
            return "What brings you a moment of true stillness today?"
        case .personalGrowth:
            return "What small step forward have you taken recently?"
        case .relationships:
            return "How have your connections with others nourished you?"
        case .career:
            return "Where do you feel most purposeful in your work?"
        case .creativity:
            return "What wants to be created through you right now?"
        case .health:
            return "How are you caring for your body and spirit today?"
        case .decision:
            return "What choice weighs on your mind?"
        case .transition:
            return "What is changing in your life, and how does it feel?"
        case .gratitude:
            return "What are three things you're grateful for today?"
        case .courage:
            return "What fear is asking you to face it with courage?"
        }
    }
}
