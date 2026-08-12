import Foundation

/// 易经真经文语料层（确定性单一真源）
///
/// 数据来源：Legge 1882（SBE XVI）公有领域英译，含卦辞、大象辞、六爻爻辞。
/// 数据由 `IChingCorpusData.json` 内嵌，离线可用，零 Bundle 依赖。
///
/// 设计意图：
/// 3B 小模型无法可靠记忆精确爻辞。QC 实测表明，若在 prompt 中喂依据让模型 elaboration，
/// G 维度反而从 1.48 跌到 1.12（模型忽略长注入、继续自由编造）。
/// 正解是外置确定性语料：由管线按卦/爻精确取用、拼接展示，G/V 维度天然满分且可审计。
/// （来源：data/live_3b_outputs_corpus.json，QC 终分 9.54，超越模板池 9.44）
final class IChingCorpus {
    static let shared = IChingCorpus()

    private var entries: [Int: Entry] = [:]

    private init() {
        load()
    }

    // MARK: - 加载

    private func load() {
        // 优先从内嵌常量解码（真机离线、零 Bundle 依赖）
        if let data = IChingCorpusData.json.data(using: .utf8),
           let file = try? JSONDecoder().decode(CorpusFile.self, from: data) {
            for (_, entry) in file.hexagrams {
                entries[entry.id] = entry
            }
            return
        }

        // 兼容：若后续将 iching_corpus.json 加入 App Target 的 Copy Bundle Resources
        if let url = Bundle.main.url(forResource: "iching_corpus", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let file = try? JSONDecoder().decode(CorpusFile.self, from: data) {
            for (_, entry) in file.hexagrams {
                entries[entry.id] = entry
            }
        }
    }

    // MARK: - 查询接口

    /// 取某卦某爻（1-6，从下往上）的爻辞（Legge 英译）
    func lineText(hexagramID: Int, line n: Int) -> String? {
        entries[hexagramID]?.lines.first(where: { $0.n == n })?.text
    }

    /// 取卦辞原文（Legge 英译）
    func judgement(hexagramID: Int) -> String? {
        entries[hexagramID]?.judgement
    }

    /// 取大象辞（Legge 英译）
    func image(hexagramID: Int) -> String? {
        entries[hexagramID]?.image
    }

    /// 取该卦全部六爻爻辞（按 1-6 顺序）；缺失时返回空数组
    func lineTexts(hexagramID: Int) -> [String] {
        guard let entry = entries[hexagramID] else { return [] }
        return (1...6).compactMap { n in
            entry.lines.first(where: { $0.n == n })?.text
        }
    }

    // MARK: - Codable

    private struct CorpusFile: Codable {
        let hexagrams: [String: Entry]
    }

    struct Entry: Codable {
        let id: Int
        let nameEN: String
        let nameCN: String
        let pinyin: String
        let judgement: String
        let image: String
        let lines: [Line]

        struct Line: Codable {
            let n: Int
            let text: String
        }
    }
}
