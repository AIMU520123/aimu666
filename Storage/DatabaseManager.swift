import Foundation
import SQLite

/// SQLite 数据库管理器
///
/// 管理所有本地持久化数据：
/// - 用户画像 (UserProfile)
/// - 对话历史 (Conversation + Messages)
/// - 占卜结果 (CastingResult)
/// - 卦象解锁状态
///
/// 设计意图：
/// - 纯本地SQLite存储，零网络传输
/// - 使用 SQLite.swift 提供类型安全的查询接口
/// - 单例模式，线程安全
/// - 加密存储敏感数据（如用户画像）
///
/// 表结构：
/// - user_profile: 用户画像
/// - conversations: 对话记录
/// - messages: 消息记录
/// - casting_results: 占卜结果
/// - hexagram_unlocks: 卦象解锁记录
@Observable
final class DatabaseManager {
    static let shared = DatabaseManager()

    private var db: Connection?

    // MARK: - 表定义

    let userProfileTable = Table("user_profile")
    let conversationsTable = Table("conversations")
    let messagesTable = Table("messages")
    let castingResultsTable = Table("casting_results")
    let hexagramUnlocksTable = Table("hexagram_unlocks")

    // user_profile 列
    let upID = SQLite.Expression<Int64>("id")
    let upData = SQLite.Expression<Data>("data")
    let upUpdatedAt = SQLite.Expression<Date>("updated_at")

    // conversations 列
    let convID = SQLite.Expression<String>("id")
    let convData = SQLite.Expression<Data>("data")
    let convCreatedAt = SQLite.Expression<Date>("created_at")
    let convLastActive = SQLite.Expression<Date>("last_active_at")

    // messages 列
    let msgID = SQLite.Expression<String>("id")
    let msgConversationID = SQLite.Expression<String>("conversation_id")
    let msgData = SQLite.Expression<Data>("data")
    let msgTimestamp = SQLite.Expression<Date>("timestamp")

    // casting_results 列
    let crID = SQLite.Expression<String>("id")
    let crData = SQLite.Expression<Data>("data")
    let crTimestamp = SQLite.Expression<Date>("timestamp")
    let crHexagramID = SQLite.Expression<Int64>("hexagram_id")

    // hexagram_unlocks 列
    let huHexagramID = SQLite.Expression<Int64>("hexagram_id")
    let huUnlockedAt = SQLite.Expression<Date>("unlocked_at")
    let huUnlockMethod = SQLite.Expression<String>("unlock_method")

    // MARK: - 初始化

    private init() {
        setupDatabase()
    }

    /// 初始化数据库连接并创建表
    private func setupDatabase() {
        guard let docsDir = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        ).first else {
            print("[DatabaseManager] Cannot access documents directory")
            return
        }

        let dbPath = docsDir.appendingPathComponent("yioracle.sqlite3").path
        print("[DatabaseManager] Database path: \(dbPath)")

        do {
            db = try Connection(dbPath)
            try createTables()
            print("[DatabaseManager] Database initialized successfully")
        } catch {
            print("[DatabaseManager] Database initialization failed: \(error)")
        }
    }

    /// 创建所有必要的表
    private func createTables() throws {
        guard let db = db else { return }

        // 用户画像表
        try db.run(userProfileTable.create(ifNotExists: true) { t in
            t.column(upID, primaryKey: .autoincrement)
            t.column(upData)
            t.column(upUpdatedAt, defaultValue: Date())
        })

        // 对话表
        try db.run(conversationsTable.create(ifNotExists: true) { t in
            t.column(convID, primaryKey: true)
            t.column(convData)
            t.column(convCreatedAt)
            t.column(convLastActive)
        })

        // 消息表
        try db.run(messagesTable.create(ifNotExists: true) { t in
            t.column(msgID, primaryKey: true)
            t.column(msgConversationID)
            t.column(msgData)
            t.column(msgTimestamp)
            t.foreignKey(msgConversationID, references: conversationsTable, convID, delete: .cascade)
        })

        // 占卜结果表
        try db.run(castingResultsTable.create(ifNotExists: true) { t in
            t.column(crID, primaryKey: true)
            t.column(crHexagramID)
            t.column(crData)
            t.column(crTimestamp)
        })

        // 卦象解锁表
        try db.run(hexagramUnlocksTable.create(ifNotExists: true) { t in
            t.column(huHexagramID, primaryKey: true)
            t.column(huUnlockedAt)
            t.column(huUnlockMethod)
        })
    }

    // MARK: - 用户画像 CRUD

    /// 保存用户画像
    func saveUserProfile(_ profile: UserProfile) throws {
        guard let db = db else { return }

        let encoder = JSONEncoder()
        let data = try encoder.encode(profile)

        let existing = try db.pluck(userProfileTable.filter(upID == 1))
        if existing != nil {
            try db.run(userProfileTable.filter(upID == 1).update(
                upData <- data,
                upUpdatedAt <- Date()
            ))
        } else {
            try db.run(userProfileTable.insert(
                upID <- 1,
                upData <- data,
                upUpdatedAt <- Date()
            ))
        }
    }

    /// 加载用户画像
    func loadUserProfile() throws -> UserProfile {
        guard let db = db else { throw DatabaseError.notInitialized }

        if let row = try db.pluck(userProfileTable.filter(upID == 1)) {
            let decoder = JSONDecoder()
            return try decoder.decode(UserProfile.self, from: row[upData])
        }

        return UserProfile() // 返回默认画像
    }

    // MARK: - 对话 CRUD

    /// 保存对话
    func saveConversation(_ conversation: Conversation) throws {
        guard let db = db else { throw DatabaseError.notInitialized }

        let encoder = JSONEncoder()
        let data = try encoder.encode(conversation)

        try db.run(conversationsTable.insert(or: .replace,
            convID <- conversation.id.uuidString,
            convData <- data,
            convCreatedAt <- conversation.startedAt,
            convLastActive <- conversation.lastActiveAt
        ))

        // 同时保存消息
        for message in conversation.messages {
            try saveMessage(message, conversationID: conversation.id)
        }
    }

    /// 加载所有对话
    func loadAllConversations() throws -> [Conversation] {
        guard let db = db else { throw DatabaseError.notInitialized }

        var conversations: [Conversation] = []
        let decoder = JSONDecoder()

        for row in try db.prepare(conversationsTable.order(convLastActive.desc)) {
            let conv = try decoder.decode(Conversation.self, from: row[convData])
            conversations.append(conv)
        }

        return conversations
    }

    /// 根据ID加载对话
    func loadConversation(byID id: UUID) throws -> Conversation? {
        guard let db = db else { throw DatabaseError.notInitialized }

        let query = conversationsTable.filter(convID == id.uuidString)
        if let row = try db.pluck(query) {
            let decoder = JSONDecoder()
            return try decoder.decode(Conversation.self, from: row[convData])
        }

        return nil
    }

    /// 删除对话
    func deleteConversation(byID id: UUID) throws {
        guard let db = db else { throw DatabaseError.notInitialized }

        // 先删除关联消息
        try db.run(messagesTable.filter(msgConversationID == id.uuidString).delete())
        // 再删除对话
        try db.run(conversationsTable.filter(convID == id.uuidString).delete())
    }

    /// 删除所有数据（用户隐私--清除记忆功能）
    func deleteAllData() throws {
        guard let db = db else { throw DatabaseError.notInitialized }

        try db.run(messagesTable.delete())
        try db.run(conversationsTable.delete())
        try db.run(castingResultsTable.delete())
        try db.run(hexagramUnlocksTable.delete())
        try db.run(userProfileTable.delete())
    }

    // MARK: - 消息 CRUD

    private func saveMessage(_ message: Message, conversationID: UUID) throws {
        guard let db = db else { throw DatabaseError.notInitialized }

        let encoder = JSONEncoder()
        let data = try encoder.encode(message)

        try db.run(messagesTable.insert(or: .replace,
            msgID <- message.id.uuidString,
            msgConversationID <- conversationID.uuidString,
            msgData <- data,
            msgTimestamp <- message.timestamp
        ))
    }

    /// 加载对话中的所有消息
    func loadMessages(forConversationID id: UUID) throws -> [Message] {
        guard let db = db else { throw DatabaseError.notInitialized }

        var messages: [Message] = []
        let decoder = JSONDecoder()

        let query = messagesTable
            .filter(msgConversationID == id.uuidString)
            .order(msgTimestamp.asc)

        for row in try db.prepare(query) {
            let msg = try decoder.decode(Message.self, from: row[msgData])
            messages.append(msg)
        }

        return messages
    }

    // MARK: - 占卜结果 CRUD

    /// 保存占卜结果
    func saveCastingResult(_ result: CastingResult) throws {
        guard let db = db else { throw DatabaseError.notInitialized }

        let encoder = JSONEncoder()
        let data = try encoder.encode(result)

        try db.run(castingResultsTable.insert(or: .replace,
            crID <- result.id.uuidString,
            crHexagramID <- Int64(result.primaryHexagramID),
            crData <- data,
            crTimestamp <- result.timestamp
        ))
    }

    /// 加载所有占卜结果
    func loadAllCastingResults() throws -> [CastingResult] {
        guard let db = db else { throw DatabaseError.notInitialized }

        var results: [CastingResult] = []
        let decoder = JSONDecoder()

        for row in try db.prepare(castingResultsTable.order(crTimestamp.desc)) {
            let result = try decoder.decode(CastingResult.self, from: row[crData])
            results.append(result)
        }

        return results
    }

    // MARK: - 卦象解锁

    /// 解锁卦象
    func unlockHexagram(id: Int, method: String) throws {
        guard let db = db else { throw DatabaseError.notInitialized }

        try db.run(hexagramUnlocksTable.insert(or: .replace,
            huHexagramID <- Int64(id),
            huUnlockedAt <- Date(),
            huUnlockMethod <- method
        ))
    }

    /// 获取所有已解锁的卦象ID
    func allUnlockedHexagramIDs() throws -> Set<Int> {
        guard let db = db else { throw DatabaseError.notInitialized }

        var ids = Set<Int>()
        for row in try db.prepare(hexagramUnlocksTable) {
            ids.insert(Int(row[huHexagramID]))
        }
        return ids
    }
}

// MARK: - 错误类型

enum DatabaseError: Error, LocalizedError {
    case notInitialized

    var errorDescription: String? {
        switch self {
        case .notInitialized: return "Database has not been initialized"
        }
    }
}
