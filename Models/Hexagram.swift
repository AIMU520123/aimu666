import Foundation
import SwiftUI

/// 六十四卦数据模型
///
/// 每一卦包含：
/// - 卦序编号（1-64）
/// - 卦名（中英文）
/// - 上下卦组成
/// - 卦象符号（六行，从下往上）
/// - 核心关键词与核心含义
/// - 五行属性
/// - 卦辞（简要）
/// - 解锁状态
struct Hexagram: Identifiable, Codable, Equatable {
    /// 卦序编号，1-64
    let id: Int

    /// 中文卦名
    let nameCN: String

    /// 英文卦名
    let nameEN: String

    /// 拼音卦名
    let namePinyin: String

    /// 上卦（外卦）名称
    let upperTrigram: String

    /// 下卦（内卦）名称
    let lowerTrigram: String

    /// 卦象六行，从下往上
    /// true = 阳爻（⚊）, false = 阴爻（⚋）
    let lines: [Bool]

    /// 核心关键词（英文）
    let keywords: [String]

    /// 核心含义简述（英文）
    let coreMeaning: String

    /// 五行属性：金/木/水/火/土
    let element: String

    /// 卦辞原文（中文）
    let judgementCN: String

    /// 卦辞英译
    let judgementEN: String

    /// 大象辞（中文）
    let imageCN: String

    /// 大象辞英译
    let imageEN: String

    /// 六爻爻辞（Legge 英译，按 1-6 从下往上）
    /// 由 IChingCorpus 在 HexagramDataStore 初始化时确定性注入。
    /// 默认值空数组，使既有构造调用无需改动即可编译。
    var lineTexts: [String] = []

    /// 是否已在当前用户的收藏中解锁
    var isUnlocked: Bool = false

    /// 解锁时间（可选）
    var unlockedAt: Date? = nil

    /// 卦象符号字符串表示
    /// 例如: ䷀ (U+4DC0) 为乾卦
    var symbol: String {
        // Unicode中六十四卦符号从 U+4DC0 开始，共64个
        guard let scalar = UnicodeScalar(0x4DC0 + id - 1) else {
            return "?"
        }
        return String(scalar)
    }

    /// 上下卦组合字符串
    var trigramComposition: String {
        "\(upperTrigram) over \(lowerTrigram)"
    }

    /// 是否为"吉"卦（简化判断：前20卦中大部分为吉）
    var isAuspicious: Bool {
        // 简化逻辑：基于卦序中的传统分类
        [1, 2, 7, 8, 11, 14, 15, 16, 19, 22, 24, 25,
         27, 30, 31, 34, 35, 37, 40, 41, 42, 45, 46,
         48, 49, 50, 55, 58, 60, 61, 63].contains(id)
    }

    /// 阴阳爻数量
    var yangCount: Int {
        lines.filter { $0 }.count
    }

    var yinCount: Int {
        lines.filter { !$0 }.count
    }
}

// MARK: - 八卦基础数据

/// 八卦（三画卦）基础定义
struct Trigram: Identifiable, Codable {
    let id: Int
    let nameCN: String
    let nameEN: String
    let symbol: String    // 卦符文字表示
    let lines: [Bool]     // 三行，从下往上
    let nature: String    // 象征：天/地/雷/风/水/火/山/泽
    let element: String   // 五行
    let direction: String // 方位

    static let all: [Trigram] = [
        .init(id: 1, nameCN: "乾", nameEN: "Qian", symbol: "☰",
              lines: [true, true, true], nature: "Heaven", element: "Metal", direction: "Northwest"),
        .init(id: 2, nameCN: "兑", nameEN: "Dui", symbol: "☱",
              lines: [true, true, false], nature: "Lake", element: "Metal", direction: "West"),
        .init(id: 3, nameCN: "离", nameEN: "Li", symbol: "☲",
              lines: [true, false, true], nature: "Fire", element: "Fire", direction: "South"),
        .init(id: 4, nameCN: "震", nameEN: "Zhen", symbol: "☳",
              lines: [true, false, false], nature: "Thunder", element: "Wood", direction: "East"),
        .init(id: 5, nameCN: "巽", nameEN: "Xun", symbol: "☴",
              lines: [false, true, true], nature: "Wind", element: "Wood", direction: "Southeast"),
        .init(id: 6, nameCN: "坎", nameEN: "Kan", symbol: "☵",
              lines: [false, true, false], nature: "Water", element: "Water", direction: "North"),
        .init(id: 7, nameCN: "艮", nameEN: "Gen", symbol: "☶",
              lines: [false, false, true], nature: "Mountain", element: "Earth", direction: "Northeast"),
        .init(id: 8, nameCN: "坤", nameEN: "Kun", symbol: "☷",
              lines: [false, false, false], nature: "Earth", element: "Earth", direction: "Southwest"),
    ]
}

// MARK: - 卦象线条渲染辅助

extension Hexagram {
    /// 生成用于SwiftUI渲染的阳爻/阴爻线条视图数据
    struct LineVisual: Identifiable {
        let id: Int          // 0-5，从下往上
        let isYang: Bool     // true=阳爻, false=阴爻
        let position: Int    // 第几爻（1-6，从下往上）
    }

    /// 获取渲染用的线条数据
    var lineVisuals: [LineVisual] {
        lines.enumerated().map { index, isYang in
            LineVisual(id: index, isYang: isYang, position: index + 1)
        }
    }
}
