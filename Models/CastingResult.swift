import Foundation

/// 占卜结果模型
///
/// 记录一次完整的掷币占卜过程与结果。
/// 三硬币法：投掷6次，每次结果为一个爻（从下往上构建卦象）。
///
/// 支持：
/// - 本卦（原始卦象）
/// - 变爻分析（动爻检测）
/// - 之卦（变卦，当有动爻时）
/// - 互卦（交互卦分析）
@Observable
final class CastingResult: Identifiable, Codable {
    /// 唯一标识
    let id: UUID

    /// 占卜时间
    let timestamp: Date

    /// 6次掷币结果（从下往上：初爻到上爻）
    /// 每个 CoinTossResult 包含3枚硬币的正反面
    let tossResults: [CoinTossResult]

    /// 最终生成的爻序（从下往上，true=阳爻, false=阴爻）
    let generatedLines: [Bool]

    /// 变爻索引（从下往上，0-5）
    let changingLineIndices: [Int]

    /// 本卦卦象ID
    let primaryHexagramID: Int

    /// 变卦卦象ID（如果有变爻）
    let transformedHexagramID: Int?

    /// 互卦卦象ID
    let nuclearHexagramID: Int

    /// 用户提出的问题（可选）
    var userQuestion: String?

    /// Yi的解读记录
    var yiInterpretation: String?

    /// 卦象是否已被用户收藏/标记
    var isSaved: Bool

    /// 关联的对话ID
    var conversationID: UUID?

    /// 占卜方式
    let castingMethod: CastingMethod

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        tossResults: [CoinTossResult],
        generatedLines: [Bool],
        changingLineIndices: [Int],
        primaryHexagramID: Int,
        transformedHexagramID: Int? = nil,
        nuclearHexagramID: Int,
        userQuestion: String? = nil,
        yiInterpretation: String? = nil,
        isSaved: Bool = false,
        conversationID: UUID? = nil,
        castingMethod: CastingMethod = .threeCoins
    ) {
        self.id = id
        self.timestamp = timestamp
        self.tossResults = tossResults
        self.generatedLines = generatedLines
        self.changingLineIndices = changingLineIndices
        self.primaryHexagramID = primaryHexagramID
        self.transformedHexagramID = transformedHexagramID
        self.nuclearHexagramID = nuclearHexagramID
        self.userQuestion = userQuestion
        self.yiInterpretation = yiInterpretation
        self.isSaved = isSaved
        self.conversationID = conversationID
        self.castingMethod = castingMethod
    }

    /// 是否有变爻（即卦象会转变）
    var hasChangingLines: Bool {
        !changingLineIndices.isEmpty
    }

    /// 变爻描述
    var changingLineDescription: String {
        guard hasChangingLines else { return "No changing lines" }
        let positions = changingLineIndices.map { $0 + 1 }.sorted()
        let posStr = positions.map { "Line \($0)" }.joined(separator: ", ")
        return "Changing: \(posStr)"
    }
}

// MARK: - 掷币结果

/// 单次掷币结果（3枚硬币）
struct CoinTossResult: Identifiable, Codable {
    let id: Int          // 第几次掷币（1-6）
    let coins: [CoinFace] // 3枚硬币的面

    /// 计算该次掷币的爻值
    /// 传统三硬币法：
    /// - 3个正面（老阳）= 变爻阳 → 阳爻
    /// - 2正1反（少阴）= 阴爻
    /// - 1正2反（少阳）= 阳爻
    /// - 3个反面（老阴）= 变爻阴 → 阴爻
    var lineValue: (isYang: Bool, isChanging: Bool) {
        let headsCount = coins.filter { $0 == .heads }.count
        switch headsCount {
        case 3: return (true, true)   // 老阳 — 动爻
        case 2: return (false, false) // 少阴 — 静爻
        case 1: return (true, false)  // 少阳 — 静爻
        case 0: return (false, true)  // 老阴 — 动爻
        default: return (true, false)
        }
    }
}

/// 硬币面
enum CoinFace: String, Codable, CaseIterable {
    case heads = "Heads" // 正面（阳面）
    case tails = "Tails" // 反面（阴面）

    var symbol: String {
        switch self {
        case .heads: return "⚊"
        case .tails: return "⚋"
        }
    }
}

/// 占卜方式
enum CastingMethod: String, Codable, CaseIterable {
    case threeCoins = "Three Coins"
    case yarrowStalks = "Yarrow Stalks"

    var description: String {
        switch self {
        case .threeCoins: return "Three Coins — Quick and classic"
        case .yarrowStalks: return "Yarrow Stalks — Traditional and meditative"
        }
    }
}

// MARK: - 卦象生成算法（静态工具方法）

extension CastingResult {
    /// 根据6爻结果计算本卦ID
    /// 卦象编码：下卦3爻 + 上卦3爻 → 查表
    static func calculateHexagramID(from lines: [Bool]) -> Int? {
        guard lines.count == 6 else { return nil }

        // 下卦（初爻到三爻，index 0-2）
        let lowerLines = Array(lines[0..<3])
        // 上卦（四爻到上爻，index 3-5）
        let upperLines = Array(lines[3..<6])

        let lowerTrigramID = trigramID(from: lowerLines)
        let upperTrigramID = trigramID(from: upperLines)

        guard let lower = lowerTrigramID, let upper = upperTrigramID else {
            return nil
        }

        // 64卦查找表：上卦ID * 8 + 下卦ID → 卦序
        // 简化映射（实际需完整查找表，此处使用HexagramData）
        return HexagramDataStore.shared.hexagramID(
            upperTrigram: upper, lowerTrigram: lower
        )
    }

    /// 三爻 → 八卦ID
    private static func trigramID(from lines: [Bool]) -> Int? {
        guard lines.count == 3 else { return nil }
        // 乾1 兑2 离3 震4 巽5 坎6 艮7 坤8
        let key = "\(lines[0])\(lines[1])\(lines[2])"
        let map: [String: Int] = [
            "truetruetrue": 1,       // ☰ 乾
            "truetruefalse": 2,      // ☱ 兑
            "truefalsetrue": 3,      // ☲ 离
            "truefalsefalse": 4,     // ☳ 震
            "falsetruetrue": 5,      // ☴ 巽
            "falsetruefalse": 6,     // ☵ 坎
            "falsefalsetrue": 7,     // ☶ 艮
            "falsefalsefalse": 8,    // ☷ 坤
        ]
        return map[key]
    }
}
