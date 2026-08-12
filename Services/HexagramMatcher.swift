import Foundation

/// 卦象匹配算法服务
///
/// 负责根据掷币结果匹配对应的卦象，包括：
/// 1. 六爻线条 → 本卦ID查找
/// 2. 变爻检测 → 变卦（之卦）计算
/// 3. 互卦（交互卦）计算
/// 4. 每日反思主题 → 推荐卦象匹配
///
/// 设计意图：
/// - 基于传统三硬币法规则
/// - 封装易经64卦的数学逻辑
/// - 为CastingView提供后端计算支持
/// - 为TodayReflectionView提供每日卦象推荐
@Observable
final class HexagramMatcher {
    static let shared = HexagramMatcher()

    private let dataStore = HexagramDataStore.shared
    private let conceptStore = ConceptMappingStore.shared

    private init() {}

    // MARK: - 卦象匹配

    /// 根据六爻线条匹配本卦
    /// - Parameter lines: 六爻（从下往上），true=阳爻, false=阴爻
    /// - Returns: 匹配的本卦，如果找不到则返回nil
    func matchPrimaryHexagram(from lines: [Bool]) -> Hexagram? {
        guard lines.count == 6 else { return nil }
        return dataStore.hexagram(from: lines)
    }

    /// 计算变卦（之卦）
    ///
    /// 有动爻时，将动爻的阴阳翻转得到变卦：
    /// - 老阳（变爻）翻转 → 阴爻
    /// - 老阴（变爻）翻转 → 阳爻
    /// - 静爻保持原样
    ///
    /// - Parameters:
    ///   - lines: 本卦六爻
    ///   - changingIndices: 动爻索引（0-5，从下往上）
    /// - Returns: 变卦
    func transformedHexagram(from lines: [Bool], changingIndices: [Int]) -> Hexagram? {
        guard lines.count == 6, !changingIndices.isEmpty else { return nil }

        var transformedLines = lines
        for index in changingIndices {
            guard index >= 0 && index < 6 else { continue }
            transformedLines[index].toggle() // 翻转动爻
        }

        return dataStore.hexagram(from: transformedLines)
    }

    /// 计算互卦（交互卦）
    ///
    /// 互卦由本卦的第2、3、4爻组成下卦，第3、4、5爻组成上卦：
    /// - 下卦：lines[1], lines[2], lines[3]（第2、3、4爻）
    /// - 上卦：lines[2], lines[3], lines[4]（第3、4、5爻）
    ///
    /// - Parameter lines: 本卦六爻
    /// - Returns: 互卦
    func nuclearHexagram(from lines: [Bool]) -> Hexagram? {
        guard lines.count == 6 else { return nil }

        let nuclearLower = Array(lines[1...3])  // 第2、3、4爻 → 下卦
        let nuclearUpper = Array(lines[2...4])  // 第3、4、5爻 → 上卦
        let nuclearLines = nuclearLower + nuclearUpper

        return dataStore.hexagram(from: nuclearLines)
    }

    // MARK: - 每日反思匹配

    /// 获取今日推荐的卦象
    ///
    /// 推荐逻辑：
    /// 1. 优先考虑用户活跃主题
    /// 2. 结合季节/月相推荐
    /// 3. 排除已频繁出现的卦象（保持新鲜感）
    /// 4. 随机选择保持每日的 "惊喜感"
    ///
    /// - Parameters:
    ///   - userProfile: 用户画像（含活跃主题和频繁卦象）
    ///   - date: 当前日期
    /// - Returns: 推荐卦象
    func recommendTodayHexagram(
        for userProfile: UserProfile,
        date: Date = Date()
    ) -> Hexagram {
        var candidates: [Int] = []

        // 1. 用户活跃主题的关联卦象
        for theme in userProfile.activeThemes {
            if let reflectionTheme = ReflectionTheme(rawValue: theme) {
                candidates.append(contentsOf: reflectionTheme.relatedHexagramIDs)
            }
        }

        // 2. 季节推荐卦象
        let seasonalIDs = conceptStore.seasonalHexagramIDs(for: date)
        candidates.append(contentsOf: seasonalIDs)

        // 3. 月相推荐
        let lunarIDs = conceptStore.lunarPhaseHexagramIDs(for: date)
        candidates.append(contentsOf: lunarIDs)

        // 4. 排除已频繁出现的卦象
        let frequentIDs = Set(userProfile.frequentHexagramIDs)
        let freshCandidates = candidates.filter { !frequentIDs.contains($0) }

        // 5. 随机选择一个
        let finalCandidates = freshCandidates.isEmpty ? candidates : freshCandidates
        let selectedID = finalCandidates.randomElement() ?? 1

        return dataStore.hexagram(byID: selectedID) ?? dataStore.hexagram(byID: 1)!
    }

    /// 根据用户问题推荐相关卦象
    func recommendHexagrams(for question: String, count: Int = 3) -> [Hexagram] {
        let ids = conceptStore.detectHexagrams(from: question)
        let uniqueIDs = Array(ids.prefix(count))

        return uniqueIDs.compactMap { dataStore.hexagram(byID: $0) }
    }

    // MARK: - 三硬币法爻值计算

    /// 计算单次三硬币掷出的爻值
    /// - Parameter tossResult: 掷币结果
    /// - Returns: (爻值: true=阳/false=阴, 是否动爻)
    func calculateLineValue(from tossResult: CoinTossResult) -> (isYang: Bool, isChanging: Bool) {
        return tossResult.lineValue
    }

    /// 模拟掷三硬币（六次）
    /// - Returns: 掷币结果数组（6次从下往上）
    func simulateTosses() -> [CoinTossResult] {
        return (1...6).map { round in
            let coins: [CoinFace] = (0..<3).map { _ in
                Bool.random() ? .heads : .tails
            }
            return CoinTossResult(id: round, coins: coins)
        }
    }
}

// MARK: - 卦象解锁逻辑

extension HexagramMatcher {
    /// 检查卦象是否应解锁
    ///
    /// 解锁条件：
    /// - 每日反思中自然出现的卦象
    /// - 占卜中产生的卦象
    /// - 用户完成特定"里程碑"（如连续7天反思）
    ///
    /// - Parameters:
    ///   - hexagramID: 卦象ID
    ///   - userProfile: 用户画像
    /// - Returns: 是否已解锁
    func shouldUnlock(hexagramID: Int, userProfile: UserProfile) -> Bool {
        return !userProfile.unlockedHexagramIDs.contains(hexagramID)
    }

    /// 获取收集进度描述
    func collectionSummary(for userProfile: UserProfile) -> (unlocked: Int, total: Int, progress: Double) {
        let unlocked = userProfile.unlockedHexagramIDs.count
        let total = 64
        let progress = Double(unlocked) / Double(total)
        return (unlocked, total, progress)
    }
}
