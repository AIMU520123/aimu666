import Foundation

/// 对话历史模型
///
/// 存储用户与Yi的每一次对话记录。
/// 对话记录用于：
/// 1. 记忆注入：每次新对话加载最近3轮历史
/// 2. 用户画像更新：分析对话主题和情绪
/// 3. 卦象关联：某些对话可能关联特定卦象解读
///
/// 所有数据本地SQLite存储，零上传。
@Observable
final class Conversation: Identifiable, Codable {
    /// 唯一标识
    let id: UUID

    /// 对话关联的卦象ID（可选）
    var hexagramID: Int?

    /// 锚定的起卦结果（可选）。
    /// 非空时，本段对话围绕这一次起卦连续展开：Yi 在整段对话中引用同一本卦，
    /// 并贯穿"本卦 → 变爻 → 之卦"的易经逻辑，不重新起卦、不跳卦。
    /// 为空则为自由对话（按 RAG 检索相关卦象）。
    /// 用轻量值类型锚点（纯 Codable 结构体），避免把 @Observable 类嵌套进 Codable。
    var activeCasting: ActiveCastingAnchor?

    /// 对话消息列表
    var messages: [Message]

    /// 对话开始时间
    let startedAt: Date

    /// 最后活跃时间
    var lastActiveAt: Date

    /// 对话主题标签（由AI自动提取）
    var topics: [String]

    /// 是否为已完成的对话
    var isCompleted: Bool

    /// 对话摘要（由AI生成，用于记忆检索）
    var summary: String

    /// 消息总数
    var messageCount: Int {
        messages.count
    }

    init(
        id: UUID = UUID(),
        hexagramID: Int? = nil,
        activeCasting: ActiveCastingAnchor? = nil,
        messages: [Message] = [],
        startedAt: Date = Date(),
        lastActiveAt: Date = Date(),
        topics: [String] = [],
        isCompleted: Bool = false,
        summary: String = ""
    ) {
        self.id = id
        self.hexagramID = hexagramID
        self.activeCasting = activeCasting
        self.messages = messages
        self.startedAt = startedAt
        self.lastActiveAt = lastActiveAt
        self.topics = topics
        self.isCompleted = isCompleted
        self.summary = summary
    }
}

// MARK: - 消息模型

/// 单条消息
struct Message: Identifiable, Codable, Equatable {
    /// 唯一标识
    let id: UUID

    /// 发送者角色
    let role: MessageRole

    /// 消息文本内容
    var content: String

    /// 发送时间
    let timestamp: Date

    /// 关联的卦象ID（占卜结果消息时使用）
    var attachedHexagramID: Int?

    /// 是否为系统安全提示消息
    var isSafetyNotice: Bool

    init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        timestamp: Date = Date(),
        attachedHexagramID: Int? = nil,
        isSafetyNotice: Bool = false
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.attachedHexagramID = attachedHexagramID
        self.isSafetyNotice = isSafetyNotice
    }
}

/// 消息发送者角色
enum MessageRole: String, Codable, CaseIterable {
    case user = "user"       // 用户
    case yi = "yi"           // Yi (AI Agent)
    case system = "system"   // 系统消息

    var displayName: String {
        switch self {
        case .user: return "You"
        case .yi: return "Yi"
        case .system: return "System"
        }
    }
}

// MARK: - 对话扩展：最近N轮提取

extension Array where Element == Conversation {
    /// 获取最近 N 个对话的摘要，用于LLM记忆注入
    func recentSummaries(limit: Int = 3) -> String {
        let recent = self
            .sorted(by: { $0.lastActiveAt > $1.lastActiveAt })
            .prefix(limit)

        guard !recent.isEmpty else { return "No previous conversations." }

        return recent.enumerated().map { index, conv in
            let dateStr = conv.lastActiveAt.formatted(date: .abbreviated, time: .shortened)
            let topics = conv.topics.isEmpty ? "General" : conv.topics.joined(separator: ", ")
            return "[\(index + 1)] \(dateStr) — Topics: \(topics) — \(conv.summary)"
        }.joined(separator: "\n")
    }
}

// MARK: - 起卦锚点（轻量值类型，纯 Codable）

/// 对话锚定的起卦读法快照。
///
/// 仅保存"易经逻辑"所需的最小字段（卦序 ID + 变爻索引），
/// 由 CastingResult 转换而来，作为 Conversation 的 Codable 存储，
/// 避免把 @Observable 类嵌套进 Codable 引发序列化问题。
/// 取值时再经 HexagramDataStore 还原为完整 Hexagram。
struct ActiveCastingAnchor: Codable, Equatable {
    let primaryHexagramID: Int
    let transformedHexagramID: Int?
    let nuclearHexagramID: Int?
    let changingLineIndices: [Int]   // 从下往上，0-5
    let userQuestion: String?

    init(
        primaryHexagramID: Int,
        transformedHexagramID: Int? = nil,
        nuclearHexagramID: Int? = nil,
        changingLineIndices: [Int] = [],
        userQuestion: String? = nil
    ) {
        self.primaryHexagramID = primaryHexagramID
        self.transformedHexagramID = transformedHexagramID
        self.nuclearHexagramID = nuclearHexagramID
        self.changingLineIndices = changingLineIndices
        self.userQuestion = userQuestion
    }

    /// 由一次完整起卦结果构造（失败时返回 nil）
    init?(from casting: CastingResult?) {
        guard let c = casting else { return nil }
        self.init(
            primaryHexagramID: c.primaryHexagramID,
            transformedHexagramID: c.transformedHexagramID,
            nuclearHexagramID: c.nuclearHexagramID,
            changingLineIndices: c.changingLineIndices,
            userQuestion: c.userQuestion
        )
    }
}
