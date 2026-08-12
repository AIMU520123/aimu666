import Foundation

/// 隐私声明服务
///
/// 管理 App 的隐私声明和用户数据控制功能。
/// 核心承诺：
/// - 所有数据本地存储，绝不上传任何服务器
/// - 用户随时可以删除所有记忆
/// - 不收集任何分析数据
/// - 不请求网络权限（除App Store收据验证外）
///
/// 设计意图：
/// - 这是面向海外市场的核心卖点之一
/// - 隐私声明语言需要温暖、真诚、透明（而非法律术语堆砌）
/// - 所有隐私操作用户可控
@Observable
final class PrivacyService {
    static let shared = PrivacyService()

    private let db = DatabaseManager.shared
    private let defaults = UserDefaultsManager.shared

    private init() {}

    // MARK: - 隐私声明文本

    /// 生成隐私声明内容（温暖语言版本）
    func privacyStatement() -> PrivacyStatement {
        return PrivacyStatement(
            sections: [
                PrivacySection(
                    title: "Your Data Stays With You",
                    icon: "lock.shield",
                    content: """
                    Yi Oracle is designed from the ground up to be private. Every conversation, \
                    every hexagram reading, every personal reflection — it all stays right here on \
                    your device. We don't have a server. We don't collect data. We don't even know \
                    who you are.

                    That's not just a privacy policy — it's the absence of one.
                    """
                ),
                PrivacySection(
                    title: "No Data, No Server, No Upload",
                    icon: "wifi.slash",
                    content: """
                    Yi Oracle works completely offline. The I Ching wisdom, the AI that talks to you \
                    (that's me — Yi), and all your personal data live entirely on your iPhone.

                    - No account required
                    - No cloud storage
                    - No analytics collection
                    - No third-party SDKs that track you

                    The app doesn't even request network permission. It literally cannot send your \
                    data anywhere.
                    """
                ),
                PrivacySection(
                    title: "You Control Your Memory",
                    icon: "brain.head.profile",
                    content: """
                    I (Yi) remember our conversations so I can be a better companion to you — \
                    adapting to your style, remembering what matters to you. But YOU are always \
                    in control:

                    - Delete individual conversations anytime
                    - Clear all memory with one tap
                    - Your unlocked hexagram collection is preserved if you want

                    Memory is a gift you give me, not something I take.
                    """
                ),
                PrivacySection(
                    title: "What We Store Locally",
                    icon: "doc.text",
                    content: """
                    On your device only, Yi Oracle stores:
                    - Your conversation history with Yi
                    - Your personal reflection notes
                    - Hexagrams you've discovered through reflection or casting
                    - Your preferences (language, theme, etc.)

                    That's it. Nothing more.
                    """
                ),
                PrivacySection(
                    title: "About the AI (That's Me!)",
                    icon: "sparkles",
                    content: """
                    I'm powered by a small AI model that runs entirely on your iPhone's chip. \
                    I don't connect to the internet to think. Every response I give you is \
                    generated right here, on this device, using Apple's Neural Engine.

                    This means our conversations are truly private — even I don't exist outside \
                    of your phone.
                    """
                ),
                PrivacySection(
                    title: "App Store Purchase",
                    icon: "cart",
                    content: """
                    The one-time purchase ($39.99) is verified through Apple's App Store system. \
                    We don't process payments ourselves, and we don't store your payment information.

                    Once purchased, all features are yours forever. No subscriptions. No additional \
                    charges. No tricks.
                    """
                ),
                PrivacySection(
                    title: "Delete Everything",
                    icon: "trash",
                    content: """
                    Want a fresh start? Go to Settings > Clear All Memory. This will:

                    - Delete all conversations with Yi
                    - Reset your personal profile
                    - Optionally keep your hexagram collection

                    After clearing, I'll be like a new friend — eager to get to know you again.
                    """
                ),
                PrivacySection(
                    title: "Your Trust Matters",
                    icon: "heart.text.square",
                    content: """
                    We built Yi Oracle because we believe that the most meaningful guidance comes \
                    from spaces of complete trust and privacy. When you know that what you share \
                    stays between you and your device, you can be fully honest — and that's when \
                    real wisdom emerges.

                    If you have questions about privacy, you can reach us. But honestly, there's \
                    not much we can say beyond: everything stays on your phone. Always.
                    """
                ),
            ],
            lastUpdated: Date()
        )
    }

    // MARK: - 隐私操作

    /// 清除所有用户数据
    func clearAllData(preserveCollection: Bool = true) async throws {
        // 保留卦象解锁状态
        let unlockedIDs: Set<Int>
        if preserveCollection {
            do {
                unlockedIDs = try db.allUnlockedHexagramIDs()
            } catch {
                unlockedIDs = []
            }
        } else {
            unlockedIDs = []
        }

        // 清除数据库
        try db.deleteAllData()

        // 重建用户画像（保留卦象解锁）
        let newProfile = UserProfile(
            unlockedHexagramIDs: unlockedIDs,
            isNewUser: true
        )
        try db.saveUserProfile(newProfile)

        print("[PrivacyService] All data cleared. Collection preserved: \(preserveCollection)")
    }

    /// 获取本地数据大小估算
    func estimateDataSize() -> String {
        // 计算 SQLite 数据库文件大小
        guard let docsDir = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        ).first else {
            return "Unknown"
        }

        let dbPath = docsDir.appendingPathComponent("yioracle.sqlite3")
        if let attrs = try? FileManager.default.attributesOfItem(atPath: dbPath.path),
           let fileSize = attrs[.size] as? Int64 {
            return formatBytes(fileSize)
        }

        return "< 1 MB"
    }

    // MARK: - 工具方法

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    // MARK: - 安全检查

    /// 检测消息是否包含需要安全关注的内容
    func checkSafetyConcern(in message: String) -> SafetyCheck {
        let lower = message.lowercased()

        let crisisKeywords = [
            "suicide", "kill myself", "want to die", "end my life",
            "self harm", "hurt myself", "cutting myself", "no reason to live",
        ]

        for keyword in crisisKeywords {
            if lower.contains(keyword) {
                return .crisisDetected(keyword: keyword)
            }
        }

        return .safe
    }
}

// MARK: - 相关类型

/// 隐私声明
struct PrivacyStatement: Codable {
    let sections: [PrivacySection]
    let lastUpdated: Date
}

/// 隐私声明段落
struct PrivacySection: Identifiable, Codable {
    let id = UUID()
    let title: String
    let icon: String
    let content: String
}

/// 安全检查结果
enum SafetyCheck: Equatable {
    case safe
    case crisisDetected(keyword: String)

    var needsSafetyResponse: Bool {
        if case .crisisDetected = self { return true }
        return false
    }
}
