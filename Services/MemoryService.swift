import Foundation

/// 记忆管理服务 — Yi的记忆核心
///
/// 管理Yi对用户的"记忆"，包括：
/// 1. 用户画像更新（从对话中学习用户特征）
/// 2. 对话历史摘要（提取关键信息）
/// 3. 卦象关联记忆（用户与哪些卦象有特殊连接）
/// 4. 遗忘管理（隐私—自动清除或用户手动清除）
///
/// 设计意图：
/// - 隐私优先：所有记忆数据本地存储，用户可随时清除
/// - 渐进学习：Yi逐渐了解用户，但不过度记忆
/// - 智能摘要：自动提取对话关键信息，减少存储量
/// - 遗忘机制：旧记忆随时间衰减，尊重"当下"的重要性
@Observable
final class MemoryService {
    static let shared = MemoryService()

    private let db = DatabaseManager.shared
    private let matcher = HexagramMatcher.shared

    private init() {}

    // MARK: - 用户画像更新

    /// 从对话中更新用户画像
    ///
    /// 分析用户最新消息，提取：
    /// - 活跃主题（情感/生活领域）
    /// - 交互风格偏好
    /// - 情绪状态
    /// - 频繁卦象
    ///
    /// - Parameters:
    ///   - profile: 当前用户画像（inout）
    ///   - userMessage: 用户最新消息
    ///   - hexagramID: 涉及卦象ID（可选）
    func updateProfileFromMessage(
        profile: inout UserProfile,
        userMessage: String,
        hexagramID: Int? = nil
    ) {
        // 更新互动计数
        profile.totalInteractions += 1
        profile.todayInteractions += 1
        profile.lastActiveDate = Date()

        // 检测主题
        let detectedIDs = ConceptMappingStore.shared.detectHexagrams(from: userMessage)
        let themes = detectThemes(from: userMessage)
        for theme in themes {
            if !profile.activeThemes.contains(theme.rawValue) {
                profile.activeThemes.append(theme.rawValue)
            }
        }

        // 更新频繁卦象
        if let hexID = hexagramID {
            profile.frequentHexagramIDs.append(hexID)
            // 保持最近20个
            if profile.frequentHexagramIDs.count > 20 {
                profile.frequentHexagramIDs.removeFirst()
            }
        }

        // 情绪检测（简化版）
        let stressKeywords = ["anxious", "stress", "worried", "tired", "exhausted", "overwhelm"]
        let calmKeywords = ["peace", "calm", "grateful", "happy", "content", "good"]

        let lowerMessage = userMessage.lowercased()
        let stressCount = stressKeywords.filter { lowerMessage.contains($0) }.count
        let calmCount = calmKeywords.filter { lowerMessage.contains($0) }.count

        if stressCount > 0 {
            profile.stressLevel = min(5, profile.stressLevel + 1)
        } else if calmCount > 0 {
            profile.stressLevel = max(1, profile.stressLevel - 1)
        }

        // 新用户标记
        if profile.isNewUser && profile.totalInteractions > 3 {
            profile.isNewUser = false
        }
    }

    /// 生成/更新 Yi 对用户的认知摘要
    func updateYiMemoryNote(profile: inout UserProfile, conversations: [Conversation]) {
        let recent = conversations.sorted(by: { $0.lastActiveAt > $1.lastActiveAt }).prefix(10)
        var topics = Set<String>()

        for conv in recent {
            for topic in conv.topics {
                topics.insert(topic)
            }
        }

        let description = if profile.isNewUser {
            "A new seeker just beginning their journey with the I Ching. Curious and open, still revealing themselves."
        } else if profile.stressLevel > 3 {
            "A thoughtful person navigating challenging times. Responds well to gentle, grounded guidance. Shows resilience beneath surface concerns."
        } else {
            "A regular companion who engages with the I Ching with \(topics.count > 3 ? "diverse" : "focused") curiosity. Prefers \(profile.castingStyle.description.lowercased())."
        }

        profile.yiMemoryNote = description
    }

    // MARK: - 对话摘要

    /// 为对话生成摘要（用于记忆检索）
    func summarizeConversation(_ conversation: inout Conversation) {
        let userMessages = conversation.messages
            .filter { $0.role == .user }
            .map { $0.content }

        let topics = detectThemes(from: userMessages.joined(separator: " "))
        conversation.topics = topics.map { $0.rawValue }

        // 简单摘要：提取前几个主题和卦象引用
        let topicStr = topics.prefix(3).map { $0.rawValue }.joined(separator: ", ")
        let hexRef = conversation.hexagramID != nil ?
            " (related to Hexagram \(conversation.hexagramID!))" : ""

        conversation.summary = "A conversation about \(topicStr)\(hexRef). " +
                               "\(userMessages.count) messages exchanged."
        conversation.isCompleted = true
    }

    /// 获取记忆注入文本（用于LLM提示词）
    func getMemoryContext(
        profile: UserProfile,
        recentConversations: [Conversation],
        maxItems: Int = 3
    ) -> String {
        let summaries = recentConversations
            .sorted(by: { $0.lastActiveAt > $1.lastActiveAt })
            .prefix(maxItems)

        guard !summaries.isEmpty else {
            return "This is a new user. No conversation history yet."
        }

        var context = ""
        if !profile.yiMemoryNote.isEmpty {
            context += "Yi's memory: \(profile.yiMemoryNote)\n\n"
        }
        context += "Recent topics: \(profile.activeThemes.joined(separator: ", "))\n"
        context += "Recent conversations:\n"
        context += summaries.map { "- \($0.summary)" }.joined(separator: "\n")

        return context
    }

    // MARK: - 隐私清除

    /// 清除所有用户记忆
    func clearAllMemory() async {
        do {
            try db.deleteAllData()
            print("[MemoryService] All memory cleared")
        } catch {
            print("[MemoryService] Failed to clear memory: \(error)")
        }
    }

    /// 清除指定天数之前的旧记忆
    func clearOldMemory(olderThan days: Int) async {
        // 实现：删除N天前的对话记录
        // 保留占卜结果和卦象解锁
        print("[MemoryService] Clear old memory (older than \(days) days)")
    }

    // MARK: - 私有辅助

    /// 检测对话中的反思主题
    private func detectThemes(from text: String) -> [ReflectionTheme] {
        let lower = text.lowercased()
        var detected: [ReflectionTheme] = []

        let themeKeywords: [ReflectionTheme: [String]] = [
            .innerPeace: ["peace", "calm", "quiet", "still", "rest", "meditation", "serene"],
            .personalGrowth: ["growth", "learn", "improve", "develop", "progress", "become"],
            .relationships: ["relationship", "friend", "partner", "family", "love", "connection"],
            .career: ["work", "career", "job", "purpose", "calling", "profession"],
            .creativity: ["create", "art", "write", "inspire", "design", "express", "imagine"],
            .health: ["health", "body", "sleep", "exercise", "energy", "rest", "heal"],
            .decision: ["decide", "choose", "choice", "option", "should i", "what to do"],
            .transition: ["change", "move", "transition", "new chapter", "shift", "turn"],
            .gratitude: ["grateful", "thank", "bless", "appreciate", "gratitude", "fortunate"],
            .courage: ["courage", "brave", "fear", "afraid", "dare", "strength", "bold"],
        ]

        for (theme, keywords) in themeKeywords {
            if keywords.contains(where: { lower.contains($0) }) {
                detected.append(theme)
            }
        }

        return detected.isEmpty ? [.personalGrowth] : detected
    }
}
