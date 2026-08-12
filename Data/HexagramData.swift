import Foundation

/// 六十四卦完整索引数据 — 硬编码数据源
///
/// 提供全部64卦的基础信息，包括：
/// - 卦序、卦名（中/英/拼音）
/// - 上下卦对应关系
/// - 六爻阴阳排列
/// - 核心关键词与含义
/// - 五行属性
/// - 卦辞与大象辞
///
/// 设计意图：
/// - 64卦是易经App的核心知识库，需要离线可用
/// - 硬编码在Swift中，零运行时网络请求
/// - 数据与Hexagram模型分离，便于后期从JSON加载
///
/// 用法：
/// ```swift
/// let hexagrams = HexagramDataStore.shared.allHexagrams
/// let qian = HexagramDataStore.shared.hexagram(byID: 1)
/// ```
final class HexagramDataStore {
    static let shared = HexagramDataStore()

    /// 所有64卦的基础数据（不含用户状态）
    /// 生成后由 IChingCorpus 确定性注入六爻爻辞（真经文），
    /// 根治 3B 模型编造爻辞的问题（QC 实测 G 维度满分）。
    private(set) lazy var allHexagrams: [Hexagram] = {
        let base = generateHexagrams()
        let corpus = IChingCorpus.shared
        return base.map { hex in
            var enriched = hex
            enriched.lineTexts = corpus.lineTexts(hexagramID: hex.id)
            return enriched
        }
    }()

    /// 上下卦查找表：上卦ID * 8 + 下卦ID → 卦序
    private(set) lazy var lookupTable: [String: Int] = generateLookupTable()

    private init() {}

    /// 按ID查找卦象
    func hexagram(byID id: Int) -> Hexagram? {
        allHexagrams.first { $0.id == id }
    }

    /// 根据上下卦ID查找卦序
    func hexagramID(upperTrigram upper: Int, lowerTrigram lower: Int) -> Int? {
        let key = "\(upper)_\(lower)"
        return lookupTable[key]
    }

    /// 根据爻线查找卦象
    func hexagram(from lines: [Bool]) -> Hexagram? {
        guard lines.count == 6 else { return nil }

        for hex in allHexagrams where hex.lines == lines {
            return hex
        }
        return nil
    }

    // MARK: - 查找表生成

    private func generateLookupTable() -> [String: Int] {
        var table: [String: Int] = [:]

        for hex in allHexagrams {
            // 从卦序倒推上下卦
            let upperID = Trigram.all.first { $0.lines == Array(hex.lines[3..<6]) }?.id ?? 0
            let lowerID = Trigram.all.first { $0.lines == Array(hex.lines[0..<3]) }?.id ?? 0
            table["\(upperID)_\(lowerID)"] = hex.id
        }

        return table
    }

    // MARK: - 64卦数据生成

    private func generateHexagrams() -> [Hexagram] {
        [
            // 1. 乾为天
            Hexagram(
                id: 1, nameCN: "乾为天", nameEN: "The Creative", namePinyin: "Qian Wei Tian",
                upperTrigram: "Qian", lowerTrigram: "Qian",
                lines: [true, true, true, true, true, true],
                keywords: ["creativity", "strength", "initiative", "persistence"],
                coreMeaning: "The primal power of creation and initiative. Time to take bold, authentic action aligned with your highest vision.",
                element: "Metal",
                judgementCN: "元亨利贞",
                judgementEN: "Sublime success through perseverance.",
                imageCN: "天行健，君子以自强不息",
                imageEN: "Heaven moves with vigor. The noble person ceaselessly strengthens themselves."
            ),
            // 2. 坤为地
            Hexagram(
                id: 2, nameCN: "坤为地", nameEN: "The Receptive", namePinyin: "Kun Wei Di",
                upperTrigram: "Kun", lowerTrigram: "Kun",
                lines: [false, false, false, false, false, false],
                keywords: ["receptivity", "nurturing", "patience", "devotion"],
                coreMeaning: "The power of receptivity and nurturing. Success comes through yielding, supporting, and patient devotion.",
                element: "Earth",
                judgementCN: "元亨。利牝马之贞。",
                judgementEN: "Sublime success through the perseverance of the mare.",
                imageCN: "地势坤，君子以厚德载物",
                imageEN: "The earth supports all. The noble person carries things with generous virtue."
            ),
            // 3. 水雷屯
            Hexagram(
                id: 3, nameCN: "水雷屯", nameEN: "Difficulty at the Beginning", namePinyin: "Shui Lei Zhun",
                upperTrigram: "Kan", lowerTrigram: "Zhen",
                lines: [true, false, false, false, true, false],
                keywords: ["beginning", "struggle", "birth", "chaos"],
                coreMeaning: "The chaos and difficulty of new beginnings. Patience and steady effort will bring order from the initial confusion.",
                element: "Water",
                judgementCN: "元亨利贞。勿用有攸往。",
                judgementEN: "Sublime success. Do not act hastily.",
                imageCN: "云雷屯，君子以经纶",
                imageEN: "Clouds and thunder gather. The noble person brings order from chaos."
            ),
            // 4. 山水蒙
            Hexagram(
                id: 4, nameCN: "山水蒙", nameEN: "Youthful Folly", namePinyin: "Shan Shui Meng",
                upperTrigram: "Gen", lowerTrigram: "Kan",
                lines: [false, true, false, false, false, true],
                keywords: ["learning", "inexperience", "curiosity", "growth"],
                coreMeaning: "The inexperience of youth seeking wisdom. Ask gently, and wisdom will be revealed in its own time.",
                element: "Earth",
                judgementCN: "亨。匪我求童蒙，童蒙求我。",
                judgementEN: "Success. It is not I who seek the young fool; the young fool seeks me.",
                imageCN: "山下出泉，蒙。君子以果行育德。",
                imageEN: "A spring emerges at the mountain's foot. Nurture virtue through decisive action."
            ),
            // 5. 水天需
            Hexagram(
                id: 5, nameCN: "水天需", nameEN: "Waiting", namePinyin: "Shui Tian Xu",
                upperTrigram: "Kan", lowerTrigram: "Qian",
                lines: [true, true, true, false, true, false],
                keywords: ["waiting", "patience", "timing", "preparation"],
                coreMeaning: "The wisdom of patient waiting. Nourish yourself while circumstances ripen. The right moment will arrive.",
                element: "Water",
                judgementCN: "需。有孚。光亨。贞吉。",
                judgementEN: "Waiting with sincerity brings brilliant success. Perseverance is fortunate.",
                imageCN: "云上于天，需。君子以饮食宴乐。",
                imageEN: "Clouds rising to heaven. The noble person nourishes body and spirit while waiting."
            ),
            // 6. 天水讼
            Hexagram(
                id: 6, nameCN: "天水讼", nameEN: "Conflict", namePinyin: "Tian Shui Song",
                upperTrigram: "Qian", lowerTrigram: "Kan",
                lines: [false, true, false, true, true, true],
                keywords: ["conflict", "dispute", "justice", "caution"],
                coreMeaning: "Conflict arises when strength meets danger. Seek resolution before matters escalate. Compromise brings peace.",
                element: "Metal",
                judgementCN: "有孚。窒惕。中吉。终凶。",
                judgementEN: "With sincerity, remain vigilant. Middle path brings fortune; extremes bring misfortune.",
                imageCN: "天与水违行，讼。君子以作事谋始。",
                imageEN: "Heaven and water move in opposite directions. Plan carefully from the start."
            ),
            // 7. 地水师
            Hexagram(
                id: 7, nameCN: "地水师", nameEN: "The Army", namePinyin: "Di Shui Shi",
                upperTrigram: "Kun", lowerTrigram: "Kan",
                lines: [false, true, false, false, false, false],
                keywords: ["discipline", "leadership", "organization", "collective"],
                coreMeaning: "The power of organized collective action. Leadership requires discipline, justice, and a worthy purpose.",
                element: "Earth",
                judgementCN: "师。贞。丈人吉。无咎。",
                judgementEN: "The army needs perseverance and a strong leader. Good fortune, no blame.",
                imageCN: "地中有水，师。君子以容民畜众。",
                imageEN: "Water stored within the earth. The noble person nourishes and leads the people."
            ),
            // 8. 水地比
            Hexagram(
                id: 8, nameCN: "水地比", nameEN: "Holding Together", namePinyin: "Shui Di Bi",
                upperTrigram: "Kan", lowerTrigram: "Kun",
                lines: [false, false, false, false, true, false],
                keywords: ["unity", "connection", "belonging", "trust"],
                coreMeaning: "The beauty of authentic connection and belonging. Draw near to what truly matters and hold together.",
                element: "Water",
                judgementCN: "比吉。原筮。元永贞。无咎。",
                judgementEN: "Holding together is good fortune. Examine the oracle once more — lasting perseverance brings no blame.",
                imageCN: "地上有水，比。先王以建万国亲诸侯。",
                imageEN: "Water upon the earth. The ancient kings built nations and drew close to allies."
            ),
            // 9. 风天小畜
            Hexagram(
                id: 9, nameCN: "风天小畜", nameEN: "Small Accumulation", namePinyin: "Feng Tian Xiao Xu",
                upperTrigram: "Xun", lowerTrigram: "Qian",
                lines: [true, true, true, false, true, true],
                keywords: ["accumulation", "restraint", "small steps", "gentle force"],
                coreMeaning: "Small accumulations of gentle influence. Patient refinement brings gradual but meaningful progress.",
                element: "Wood",
                judgementCN: "小畜。亨。密云不雨。",
                judgementEN: "Small accumulation. Success. Dark clouds but no rain yet.",
                imageCN: "风行天上，小畜。君子以懿文德。",
                imageEN: "Wind blows across heaven. The noble person refines their character through culture."
            ),
            // 10. 天泽履
            Hexagram(
                id: 10, nameCN: "天泽履", nameEN: "Treading", namePinyin: "Tian Ze Lü",
                upperTrigram: "Qian", lowerTrigram: "Dui",
                lines: [true, true, false, true, true, true],
                keywords: ["conduct", "propriety", "caution", "balance"],
                coreMeaning: "Treading carefully through life. Mindful conduct and awareness of boundaries bring safe passage.",
                element: "Metal",
                judgementCN: "履虎尾。不咥人。亨。",
                judgementEN: "Treading on the tiger's tail. It does not bite. Success.",
                imageCN: "上天下泽，履。君子以辨上下定民志。",
                imageEN: "Heaven above, lake below. Distinguish roles to establish social harmony."
            ),
            // 11. 地天泰
            Hexagram(
                id: 11, nameCN: "地天泰", nameEN: "Peace", namePinyin: "Di Tian Tai",
                upperTrigram: "Kun", lowerTrigram: "Qian",
                lines: [true, true, true, false, false, false],
                keywords: ["harmony", "peace", "prosperity", "balance"],
                coreMeaning: "Heaven and earth in harmonious union. A time of peace, prosperity, and the free flow of energy between all things.",
                element: "Earth",
                judgementCN: "泰。小往大来。吉亨。",
                judgementEN: "Peace. The small departs, the great approaches. Good fortune and success.",
                imageCN: "天地交，泰。后以财成天地之道。",
                imageEN: "Heaven and earth unite. The ruler harmonizes the way of heaven and earth."
            ),
            // 12. 天地否
            Hexagram(
                id: 12, nameCN: "天地否", nameEN: "Standstill", namePinyin: "Tian Di Pi",
                upperTrigram: "Qian", lowerTrigram: "Kun",
                lines: [false, false, false, true, true, true],
                keywords: ["obstruction", "stagnation", "withdrawal", "patience"],
                coreMeaning: "Heaven and earth disconnected. A time of obstruction and stagnation. Withdraw and preserve inner integrity.",
                element: "Metal",
                judgementCN: "否之匪人。不利君子贞。",
                judgementEN: "Standstill. Unfavorable for the noble person's perseverance.",
                imageCN: "天地不交，否。君子以俭德辟难。",
                imageEN: "Heaven and earth do not unite. The noble person withdraws with modest virtue."
            ),
            // 13. 天火同人
            Hexagram(
                id: 13, nameCN: "天火同人", nameEN: "Fellowship", namePinyin: "Tian Huo Tong Ren",
                upperTrigram: "Qian", lowerTrigram: "Li",
                lines: [true, false, true, true, true, true],
                keywords: ["community", "fellowship", "shared purpose", "openness"],
                coreMeaning: "The warmth of genuine fellowship. Opening your heart to others creates bonds of shared purpose and understanding.",
                element: "Metal",
                judgementCN: "同人于野。亨。利涉大川。",
                judgementEN: "Fellowship in the open. Success. Favorable to cross the great water.",
                imageCN: "天与火，同人。君子以类族辨物。",
                imageEN: "Heaven with fire. The noble person sorts things by their kind."
            ),
            // 14. 火天大有
            Hexagram(
                id: 14, nameCN: "火天大有", nameEN: "Great Possession", namePinyin: "Huo Tian Da You",
                upperTrigram: "Li", lowerTrigram: "Qian",
                lines: [true, true, true, false, true, true],
                keywords: ["abundance", "prosperity", "generosity", "gratitude"],
                coreMeaning: "Great possession and abundance. Share generously and remain humble — true wealth flows when it circulates freely.",
                element: "Fire",
                judgementCN: "大有。元亨。",
                judgementEN: "Great possession. Supreme success.",
                imageCN: "火在天上，大有。君子以遏恶扬善。",
                imageEN: "Fire above heaven. The noble person suppresses evil and promotes good."
            ),
            // 15. 地山谦
            Hexagram(
                id: 15, nameCN: "地山谦", nameEN: "Modesty", namePinyin: "Di Shan Qian",
                upperTrigram: "Kun", lowerTrigram: "Gen",
                lines: [false, false, true, false, false, false],
                keywords: ["humility", "modesty", "equality", "foundation"],
                coreMeaning: "The mountain bows beneath the earth. True greatness lies in humility. Elevate others to elevate yourself.",
                element: "Earth",
                judgementCN: "谦。亨。君子有终。",
                judgementEN: "Modesty. Success. The noble person brings things to completion.",
                imageCN: "地中有山，谦。君子以裒多益寡。",
                imageEN: "Mountain within the earth. The noble person reduces excess to fill deficiency."
            ),
            // 16. 雷地豫
            Hexagram(
                id: 16, nameCN: "雷地豫", nameEN: "Enthusiasm", namePinyin: "Lei Di Yu",
                upperTrigram: "Zhen", lowerTrigram: "Kun",
                lines: [false, false, false, false, false, true],
                keywords: ["enthusiasm", "joy", "movement", "harmony"],
                coreMeaning: "Thunder resounding across the earth. Enthusiasm and joy carry energy forward. Move with confidence and purpose.",
                element: "Wood",
                judgementCN: "豫。利建侯行师。",
                judgementEN: "Enthusiasm. Favorable to establish leaders and mobilize action.",
                imageCN: "雷出地奋，豫。先王以作乐崇德。",
                imageEN: "Thunder emerges from the earth. The ancient kings made music to honor virtue."
            ),
            // 17. 泽雷随
            Hexagram(
                id: 17, nameCN: "泽雷随", nameEN: "Following", namePinyin: "Ze Lei Sui",
                upperTrigram: "Dui", lowerTrigram: "Zhen",
                lines: [true, false, false, true, true, false],
                keywords: ["adaptation", "following", "flexibility", "flow"],
                coreMeaning: "Following the natural flow. Flexibility and adaptation are strengths, not weaknesses. Flow with what is.",
                element: "Metal",
                judgementCN: "随。元亨利贞。无咎。",
                judgementEN: "Following. Supreme success through perseverance. No blame.",
                imageCN: "泽中有雷，随。君子以向晦入宴息。",
                imageEN: "Thunder within the lake. The noble person rests when evening comes."
            ),
            // 18. 山风蛊
            Hexagram(
                id: 18, nameCN: "山风蛊", nameEN: "Decay", namePinyin: "Shan Feng Gu",
                upperTrigram: "Gen", lowerTrigram: "Xun",
                lines: [false, true, true, false, false, true],
                keywords: ["decay", "renewal", "correction", "healing"],
                coreMeaning: "What has decayed can be restored. This is a call to address neglected matters and begin the work of renewal.",
                element: "Earth",
                judgementCN: "蛊。元亨。利涉大川。",
                judgementEN: "Decay. Supreme success. Favorable to cross the great water.",
                imageCN: "山下有风，蛊。君子以振民育德。",
                imageEN: "Wind beneath the mountain. The noble person stirs the people and nurtures virtue."
            ),
            // 19. 地泽临
            Hexagram(
                id: 19, nameCN: "地泽临", nameEN: "Approach", namePinyin: "Di Ze Lin",
                upperTrigram: "Kun", lowerTrigram: "Dui",
                lines: [true, true, false, false, false, false],
                keywords: ["approach", "arrival", "presence", "openness"],
                coreMeaning: "Something meaningful is approaching. Stay open, attentive, and ready to receive what comes with full presence.",
                element: "Earth",
                judgementCN: "临。元亨利贞。至于八月有凶。",
                judgementEN: "Approach. Supreme success through perseverance. By the eighth month there may be misfortune.",
                imageCN: "泽上有地，临。君子以教思无穷。",
                imageEN: "Earth above the lake. The noble person teaches and reflects without end."
            ),
            // 20. 风地观
            Hexagram(
                id: 20, nameCN: "风地观", nameEN: "Contemplation", namePinyin: "Feng Di Guan",
                upperTrigram: "Xun", lowerTrigram: "Kun",
                lines: [false, false, false, false, true, true],
                keywords: ["contemplation", "observation", "clarity", "perspective"],
                coreMeaning: "Take a step back and observe. Clarity emerges through contemplation. See the larger pattern before you act.",
                element: "Wood",
                judgementCN: "观。盥而不荐。有孚颙若。",
                judgementEN: "Contemplation. The ablution is done but not the offering. Sincere reverence.",
                imageCN: "风行地上，观。先王以省方观民设教。",
                imageEN: "Wind moves across the earth. The ancient kings surveyed the land and taught the people."
            ),
            // 21. 火雷噬嗑
            Hexagram(
                id: 21, nameCN: "火雷噬嗑", nameEN: "Biting Through", namePinyin: "Huo Lei Shi Ke",
                upperTrigram: "Li", lowerTrigram: "Zhen",
                lines: [true, false, false, false, true, true],
                keywords: ["obstacle", "determination", "breakthrough", "justice"],
                coreMeaning: "Biting through obstacles. Direct confrontation of what blocks your path. Justice and determination clear the way.",
                element: "Fire",
                judgementCN: "噬嗑。亨。利用狱。",
                judgementEN: "Biting through. Success. Favorable for administering justice.",
                imageCN: "雷电噬嗑。先王以明罚敕法。",
                imageEN: "Thunder and lightning. The ancient kings clarified punishments and enforced laws."
            ),
            // 22. 山火贲
            Hexagram(
                id: 22, nameCN: "山火贲", nameEN: "Grace", namePinyin: "Shan Huo Bi",
                upperTrigram: "Gen", lowerTrigram: "Li",
                lines: [true, false, true, false, false, true],
                keywords: ["beauty", "grace", "form", "elegance"],
                coreMeaning: "Grace and beauty adorn life's structure. Elegance matters, but substance underlies all true beauty.",
                element: "Earth",
                judgementCN: "贲。亨。小利有攸往。",
                judgementEN: "Grace. Success. Small advantage in going forward.",
                imageCN: "山下有火，贲。君子以明庶政无敢折狱。",
                imageEN: "Fire at the mountain's foot. The noble person illuminates governance with clarity."
            ),
            // 23. 山地剥
            Hexagram(
                id: 23, nameCN: "山地剥", nameEN: "Splitting Apart", namePinyin: "Shan Di Bo",
                upperTrigram: "Gen", lowerTrigram: "Kun",
                lines: [false, false, false, false, false, true],
                keywords: ["erosion", "collapse", "rest", "endurance"],
                coreMeaning: "Things are splitting apart. What is unsustainable falls away. Wait and preserve your strength for renewal.",
                element: "Earth",
                judgementCN: "剥。不利有攸往。",
                judgementEN: "Splitting apart. Not favorable to go forward.",
                imageCN: "山附于地，剥。上以厚下安宅。",
                imageEN: "Mountain crumbling to earth. The superior person strengthens the foundation."
            ),
            // 24. 地雷复
            Hexagram(
                id: 24, nameCN: "地雷复", nameEN: "Return", namePinyin: "Di Lei Fu",
                upperTrigram: "Kun", lowerTrigram: "Zhen",
                lines: [true, false, false, false, false, false],
                keywords: ["return", "renewal", "spring", "fresh start"],
                coreMeaning: "The turning point — yang energy returns. A fresh start emerges from stillness. Rest and let renewal come naturally.",
                element: "Earth",
                judgementCN: "复。亨。出入无疾。",
                judgementEN: "Return. Success. Going out and coming in without harm.",
                imageCN: "雷在地中，复。先王以至日闭关。",
                imageEN: "Thunder within the earth. The ancient kings closed the passes at the solstice."
            ),
            // 25. 天雷无妄
            Hexagram(
                id: 25, nameCN: "天雷无妄", nameEN: "Innocence", namePinyin: "Tian Lei Wu Wang",
                upperTrigram: "Qian", lowerTrigram: "Zhen",
                lines: [true, false, false, true, true, true],
                keywords: ["innocence", "authenticity", "spontaneity", "naturalness"],
                coreMeaning: "The unexpected gift of innocence. Act from authentic nature, without calculation or pretense. Spontaneity brings true success.",
                element: "Metal",
                judgementCN: "无妄。元亨利贞。其匪正有眚。",
                judgementEN: "Innocence. Supreme success through perseverance. Deviation brings misfortune.",
                imageCN: "天下雷行，物与无妄。先王以茂对时育万物。",
                imageEN: "Thunder beneath heaven. The ancient kings nurtured all beings in their seasons."
            ),
            // 26. 山天大畜
            Hexagram(
                id: 26, nameCN: "山天大畜", nameEN: "Great Accumulation", namePinyin: "Shan Tian Da Xu",
                upperTrigram: "Gen", lowerTrigram: "Qian",
                lines: [true, true, true, false, false, true],
                keywords: ["accumulation", "wisdom", "reserve", "preparation"],
                coreMeaning: "Great accumulation of wisdom and strength. Store your energy for the right moment. Cultivate inner resources.",
                element: "Earth",
                judgementCN: "大畜。利贞。不家食吉。",
                judgementEN: "Great accumulation. Favorable perseverance. Not eating at home brings fortune.",
                imageCN: "天在山中，大畜。君子以多识前言往行。",
                imageEN: "Heaven within the mountain. The noble person studies the words and deeds of the past."
            ),
            // 27. 山雷颐
            Hexagram(
                id: 27, nameCN: "山雷颐", nameEN: "Nourishment", namePinyin: "Shan Lei Yi",
                upperTrigram: "Gen", lowerTrigram: "Zhen",
                lines: [true, false, false, false, false, true],
                keywords: ["nourishment", "sustenance", "self-care", "health"],
                coreMeaning: "How do you nourish yourself — body, mind, and spirit? Choose your sources of sustenance wisely.",
                element: "Earth",
                judgementCN: "颐。贞吉。观颐。自求口实。",
                judgementEN: "Nourishment. Perseverance brings fortune. Observe how you are nourished and seek your own sustenance.",
                imageCN: "山下有雷，颐。君子以慎言语节饮食。",
                imageEN: "Thunder beneath the mountain. The noble person is careful with words and moderate in consumption."
            ),
            // 28. 泽风大过
            Hexagram(
                id: 28, nameCN: "泽风大过", nameEN: "Great Excess", namePinyin: "Ze Feng Da Guo",
                upperTrigram: "Dui", lowerTrigram: "Xun",
                lines: [false, true, true, true, true, false],
                keywords: ["excess", "crisis", "transition", "independence"],
                coreMeaning: "The beam is bending under excessive weight. Extraordinary times call for extraordinary measures. Act with courage.",
                element: "Metal",
                judgementCN: "大过。栋桡。利有攸往。亨。",
                judgementEN: "Great excess. The ridgepole sags. Favorable to move forward. Success.",
                imageCN: "泽灭木，大过。君子以独立不惧。",
                imageEN: "Lake rises above trees. The noble person stands alone without fear."
            ),
            // 29. 坎为水
            Hexagram(
                id: 29, nameCN: "坎为水", nameEN: "The Abysmal", namePinyin: "Kan Wei Shui",
                upperTrigram: "Kan", lowerTrigram: "Kan",
                lines: [false, true, false, false, true, false],
                keywords: ["danger", "depth", "flow", "courage"],
                coreMeaning: "Water doubled — facing the abyss. Danger teaches depth. Flow with the current rather than fighting it. Courage through sincerity.",
                element: "Water",
                judgementCN: "习坎。有孚。维心亨。",
                judgementEN: "The abyss repeated. With sincerity, the heart finds success.",
                imageCN: "水洊至，习坎。君子以常德行，习教事。",
                imageEN: "Water flows continuously. The noble person maintains steady virtue and practices teaching."
            ),
            // 30. 离为火
            Hexagram(
                id: 30, nameCN: "离为火", nameEN: "The Clinging", namePinyin: "Li Wei Huo",
                upperTrigram: "Li", lowerTrigram: "Li",
                lines: [true, false, true, true, false, true],
                keywords: ["clarity", "light", "attachment", "illumination"],
                coreMeaning: "Fire clinging to what nourishes it. Clarity and illumination. Attach yourself to what is true and bright.",
                element: "Fire",
                judgementCN: "离。利贞。亨。畜牝牛吉。",
                judgementEN: "The clinging. Favorable perseverance. Success. Raising a cow brings fortune.",
                imageCN: "明两作，离。大人以继明照于四方。",
                imageEN: "Light doubled. The great person illuminates the four quarters with continuous brightness."
            ),
            // 31. 泽山咸
            Hexagram(
                id: 31, nameCN: "泽山咸", nameEN: "Influence", namePinyin: "Ze Shan Xian",
                upperTrigram: "Dui", lowerTrigram: "Gen",
                lines: [false, false, true, true, true, false],
                keywords: ["influence", "attraction", "response", "feeling"],
                coreMeaning: "Mutual influence and attraction. The gentle pull between hearts. Open yourself to genuine connection.",
                element: "Metal",
                judgementCN: "咸。亨利贞。取女吉。",
                judgementEN: "Influence. Success through perseverance. Taking a wife brings fortune.",
                imageCN: "山上有泽，咸。君子以虚受人。",
                imageEN: "Lake on the mountain. The noble person receives others with openness and humility."
            ),
            // 32. 雷风恒
            Hexagram(
                id: 32, nameCN: "雷风恒", nameEN: "Duration", namePinyin: "Lei Feng Heng",
                upperTrigram: "Zhen", lowerTrigram: "Xun",
                lines: [false, true, true, false, false, true],
                keywords: ["endurance", "constancy", "commitment", "stability"],
                coreMeaning: "Thunder and wind enduring together. Lasting commitment creates stability. Persevere in what truly matters.",
                element: "Wood",
                judgementCN: "恒。亨。无咎。利贞。",
                judgementEN: "Duration. Success. No blame. Favorable perseverance.",
                imageCN: "雷风，恒。君子以立不易方。",
                imageEN: "Thunder and wind. The noble person stands firm without changing direction."
            ),
            // 33. 天山遁
            Hexagram(
                id: 33, nameCN: "天山遁", nameEN: "Retreat", namePinyin: "Tian Shan Dun",
                upperTrigram: "Qian", lowerTrigram: "Gen",
                lines: [false, false, true, true, true, true],
                keywords: ["retreat", "withdrawal", "boundary", "self-care"],
                coreMeaning: "Strategic retreat is not defeat. Step back gracefully to preserve your strength for a more favorable moment.",
                element: "Metal",
                judgementCN: "遁。亨。小利贞。",
                judgementEN: "Retreat. Success. Small perseverance brings benefit.",
                imageCN: "天下有山，遁。君子以远小人。",
                imageEN: "Mountain beneath heaven. The noble person keeps distance from petty influences."
            ),
            // 34. 雷天大壮
            Hexagram(
                id: 34, nameCN: "雷天大壮", nameEN: "Great Power", namePinyin: "Lei Tian Da Zhuang",
                upperTrigram: "Zhen", lowerTrigram: "Qian",
                lines: [true, true, true, true, false, false],
                keywords: ["power", "strength", "confidence", "restraint"],
                coreMeaning: "Great power and confidence. Use strength wisely — with restraint and in alignment with what is right.",
                element: "Wood",
                judgementCN: "大壮。利贞。",
                judgementEN: "Great power. Favorable perseverance.",
                imageCN: "雷在天上，大壮。君子以非礼弗履。",
                imageEN: "Thunder in heaven. The noble person does nothing that violates propriety."
            ),
            // 35. 火地晋
            Hexagram(
                id: 35, nameCN: "火地晋", nameEN: "Progress", namePinyin: "Huo Di Jin",
                upperTrigram: "Li", lowerTrigram: "Kun",
                lines: [false, false, false, false, true, true],
                keywords: ["progress", "advancement", "recognition", "growth"],
                coreMeaning: "The sun rising over the earth — steady progress. Your efforts are being recognized. Advance with gentle confidence.",
                element: "Fire",
                judgementCN: "晋。康侯用锡马蕃庶。",
                judgementEN: "Progress. The enlightened leader is rewarded with horses and abundance.",
                imageCN: "明出地上，晋。君子以自昭明德。",
                imageEN: "Light rising above earth. The noble person illuminates their own bright virtue."
            ),
            // 36. 地火明夷
            Hexagram(
                id: 36, nameCN: "地火明夷", nameEN: "Darkening of the Light", namePinyin: "Di Huo Ming Yi",
                upperTrigram: "Kun", lowerTrigram: "Li",
                lines: [true, false, true, false, false, false],
                keywords: ["adversity", "darkness", "resilience", "inner light"],
                coreMeaning: "Light hidden beneath the earth. In dark times, protect your inner light. Resilience through quiet persistence.",
                element: "Earth",
                judgementCN: "明夷。利艰贞。",
                judgementEN: "Darkening of the light. Favorable to persevere through hardship.",
                imageCN: "明入地中，明夷。君子以莅众用晦而明。",
                imageEN: "Light enters the earth. The noble person leads through darkness with hidden clarity."
            ),
            // 37. 风火家人
            Hexagram(
                id: 37, nameCN: "风火家人", nameEN: "The Family", namePinyin: "Feng Huo Jia Ren",
                upperTrigram: "Xun", lowerTrigram: "Li",
                lines: [true, false, true, true, true, false],
                keywords: ["family", "home", "nurturing", "foundation"],
                coreMeaning: "The warmth of family and home. True community begins with how you nurture your closest relationships.",
                element: "Wood",
                judgementCN: "家人。利女贞。",
                judgementEN: "The family. Favorable for the perseverance of the nurturing one.",
                imageCN: "风自火出，家人。君子以言有物而行有恒。",
                imageEN: "Wind emerges from fire. Words should have substance, actions should have constancy."
            ),
            // 38. 火泽睽
            Hexagram(
                id: 38, nameCN: "火泽睽", nameEN: "Opposition", namePinyin: "Huo Ze Kui",
                upperTrigram: "Li", lowerTrigram: "Dui",
                lines: [true, true, false, false, true, true],
                keywords: ["opposition", "difference", "misunderstanding", "reconciliation"],
                coreMeaning: "Fire above, lake below — opposing forces. Differences don't mean separation. Find unity within diversity.",
                element: "Fire",
                judgementCN: "睽。小事吉。",
                judgementEN: "Opposition. Small matters bring fortune.",
                imageCN: "上火下泽，睽。君子以同而异。",
                imageEN: "Fire above, lake below. The noble person finds unity within diversity."
            ),
            // 39. 水山蹇
            Hexagram(
                id: 39, nameCN: "水山蹇", nameEN: "Obstruction", namePinyin: "Shui Shan Jian",
                upperTrigram: "Kan", lowerTrigram: "Gen",
                lines: [false, false, true, false, true, false],
                keywords: ["obstacle", "difficulty", "adaptation", "wisdom"],
                coreMeaning: "Water before the mountain — an obstruction. When the path is blocked, seek a wiser way around.",
                element: "Water",
                judgementCN: "蹇。利西南。不利东北。",
                judgementEN: "Obstruction. The southwest is favorable. The northeast is not.",
                imageCN: "山上有水，蹇。君子以反身修德。",
                imageEN: "Water on the mountain. The noble person turns inward to cultivate virtue."
            ),
            // 40. 雷水解
            Hexagram(
                id: 40, nameCN: "雷水解", nameEN: "Deliverance", namePinyin: "Lei Shui Xie",
                upperTrigram: "Zhen", lowerTrigram: "Kan",
                lines: [false, true, false, false, false, true],
                keywords: ["release", "resolution", "freedom", "relief"],
                coreMeaning: "Thunder and rain — deliverance from tension. Release what no longer serves. Forgiveness brings liberation.",
                element: "Wood",
                judgementCN: "解。利西南。无所往。其来复吉。",
                judgementEN: "Deliverance. The southwest is favorable. Return brings fortune.",
                imageCN: "雷雨作，解。君子以赦过宥罪。",
                imageEN: "Thunder and rain arise. The noble person forgives mistakes and pardons wrongs."
            ),
            // 41. 山泽损
            Hexagram(
                id: 41, nameCN: "山泽损", nameEN: "Decrease", namePinyin: "Shan Ze Sun",
                upperTrigram: "Gen", lowerTrigram: "Dui",
                lines: [true, true, false, false, false, true],
                keywords: ["decrease", "sacrifice", "simplicity", "reduction"],
                coreMeaning: "Decrease of the lower to benefit the higher. Sometimes less is more. Simplify with purpose.",
                element: "Earth",
                judgementCN: "损。有孚。元吉。无咎。",
                judgementEN: "Decrease. With sincerity, supreme fortune. No blame.",
                imageCN: "山下有泽，损。君子以惩忿窒欲。",
                imageEN: "Lake beneath the mountain. The noble person restrains anger and curbs desire."
            ),
            // 42. 风雷益
            Hexagram(
                id: 42, nameCN: "风雷益", nameEN: "Increase", namePinyin: "Feng Lei Yi",
                upperTrigram: "Xun", lowerTrigram: "Zhen",
                lines: [true, false, false, false, true, true],
                keywords: ["increase", "growth", "abundance", "support"],
                coreMeaning: "Wind and thunder — increase and growth. When you see what is good, embrace it. When you err, correct it.",
                element: "Wood",
                judgementCN: "益。利有攸往。利涉大川。",
                judgementEN: "Increase. Favorable to go forward. Favorable to cross the great water.",
                imageCN: "风雷，益。君子以见善则迁，有过则改。",
                imageEN: "Wind and thunder. The noble person moves toward what is good and corrects what is wrong."
            ),
            // 43. 泽天夬
            Hexagram(
                id: 43, nameCN: "泽天夬", nameEN: "Breakthrough", namePinyin: "Ze Tian Guai",
                upperTrigram: "Dui", lowerTrigram: "Qian",
                lines: [true, true, true, true, true, false],
                keywords: ["decision", "breakthrough", "resolution", "honesty"],
                coreMeaning: "A decisive breakthrough. The time for resolution has come. Act with clarity, honesty, and firmness.",
                element: "Metal",
                judgementCN: "夬。扬于王庭。孚号有厉。",
                judgementEN: "Breakthrough. Proclaimed openly in the court. Sincere warning of danger.",
                imageCN: "泽上于天，夬。君子以施禄及下。",
                imageEN: "Lake rising to heaven. The noble person shares blessings generously."
            ),
            // 44. 天风姤
            Hexagram(
                id: 44, nameCN: "天风姤", nameEN: "Coming to Meet", namePinyin: "Tian Feng Gou",
                upperTrigram: "Qian", lowerTrigram: "Xun",
                lines: [false, true, true, true, true, true],
                keywords: ["encounter", "meeting", "chance", "temptation"],
                coreMeaning: "An unexpected encounter. Be mindful of what you welcome — some meetings carry both opportunity and caution.",
                element: "Metal",
                judgementCN: "姤。女壮。勿用取女。",
                judgementEN: "Coming to meet. The woman is strong. Do not take this woman.",
                imageCN: "天下有风，姤。后以施命诰四方。",
                imageEN: "Wind beneath heaven. The ruler issues commands to the four directions."
            ),
            // 45. 泽地萃
            Hexagram(
                id: 45, nameCN: "泽地萃", nameEN: "Gathering Together", namePinyin: "Ze Di Cui",
                upperTrigram: "Dui", lowerTrigram: "Kun",
                lines: [false, false, false, true, true, false],
                keywords: ["gathering", "community", "celebration", "unity"],
                coreMeaning: "Waters gathering on the earth. Community and collective strength. Come together and celebrate shared purpose.",
                element: "Metal",
                judgementCN: "萃。亨。王假有庙。",
                judgementEN: "Gathering together. Success. The king approaches the temple.",
                imageCN: "泽上于地，萃。君子以除戎器戒不虞。",
                imageEN: "Lake upon the earth. The noble person maintains order and prepares for the unexpected."
            ),
            // 46. 地风升
            Hexagram(
                id: 46, nameCN: "地风升", nameEN: "Pushing Upward", namePinyin: "Di Feng Sheng",
                upperTrigram: "Kun", lowerTrigram: "Xun",
                lines: [false, true, true, false, false, false],
                keywords: ["ascension", "growth", "persistence", "steady climb"],
                coreMeaning: "Wood growing through the earth — steady upward progress. Small consistent efforts lead to remarkable heights.",
                element: "Earth",
                judgementCN: "升。元亨。用见大人。",
                judgementEN: "Pushing upward. Supreme success. Seek the guidance of a great person.",
                imageCN: "地中生木，升。君子以顺德积小以高大。",
                imageEN: "Wood growing from earth. The noble person accumulates small virtues to reach great heights."
            ),
            // 47. 泽水困
            Hexagram(
                id: 47, nameCN: "泽水困", nameEN: "Oppression", namePinyin: "Ze Shui Kun",
                upperTrigram: "Dui", lowerTrigram: "Kan",
                lines: [false, true, false, true, true, false],
                keywords: ["exhaustion", "oppression", "endurance", "inner truth"],
                coreMeaning: "Water beneath the lake — exhaustion and oppression. When words fail, let inner truth be your guide through difficulty.",
                element: "Metal",
                judgementCN: "困。亨。贞。大人吉。",
                judgementEN: "Oppression. Success through perseverance. The great person finds fortune.",
                imageCN: "泽无水，困。君子以致命遂志。",
                imageEN: "Lake without water. The noble person stakes life on fulfilling their purpose."
            ),
            // 48. 水风井
            Hexagram(
                id: 48, nameCN: "水风井", nameEN: "The Well", namePinyin: "Shui Feng Jing",
                upperTrigram: "Kan", lowerTrigram: "Xun",
                lines: [false, true, true, false, true, false],
                keywords: ["foundation", "source", "depth", "constancy"],
                coreMeaning: "The well — deep and constant. True sustenance comes from enduring sources. Draw deeply from what nourishes your spirit.",
                element: "Water",
                judgementCN: "井。改邑不改井。无丧无得。",
                judgementEN: "The well. The town changes but the well remains. Nothing lost, nothing gained.",
                imageCN: "木上有水，井。君子以劳民劝相。",
                imageEN: "Water over wood. The noble person encourages mutual support among the people."
            ),
            // 49. 泽火革
            Hexagram(
                id: 49, nameCN: "泽火革", nameEN: "Revolution", namePinyin: "Ze Huo Ge",
                upperTrigram: "Dui", lowerTrigram: "Li",
                lines: [true, false, true, true, true, false],
                keywords: ["change", "transformation", "revolution", "renewal"],
                coreMeaning: "Fire and water clash — radical transformation. When the old no longer serves, profound change becomes necessary and auspicious.",
                element: "Metal",
                judgementCN: "革。己日乃孚。元亨利贞。",
                judgementEN: "Revolution. On the day of change, you will be trusted. Supreme success through perseverance.",
                imageCN: "泽中有火，革。君子以治历明时。",
                imageEN: "Fire within the lake. The noble person orders the calendar and clarifies the seasons."
            ),
            // 50. 火风鼎
            Hexagram(
                id: 50, nameCN: "火风鼎", nameEN: "The Cauldron", namePinyin: "Huo Feng Ding",
                upperTrigram: "Li", lowerTrigram: "Xun",
                lines: [false, true, true, false, true, true],
                keywords: ["transformation", "nourishment", "alchemy", "refinement"],
                coreMeaning: "The sacred cauldron — transformation through fire. Refine your life as if cooking a sacred offering. Transform the raw into the sublime.",
                element: "Fire",
                judgementCN: "鼎。元吉。亨。",
                judgementEN: "The cauldron. Supreme fortune. Success.",
                imageCN: "木上有火，鼎。君子以正位凝命。",
                imageEN: "Fire over wood. The noble person fixes their position and consolidates their destiny."
            ),
            // 51. 震为雷
            Hexagram(
                id: 51, nameCN: "震为雷", nameEN: "The Arousing", namePinyin: "Zhen Wei Lei",
                upperTrigram: "Zhen", lowerTrigram: "Zhen",
                lines: [true, false, false, true, false, false],
                keywords: ["shock", "awakening", "awareness", "alertness"],
                coreMeaning: "Thunder doubled — a sudden awakening. Shock clarifies. Let startling moments bring you into heightened awareness.",
                element: "Wood",
                judgementCN: "震。亨。震来虩虩。笑言哑哑。",
                judgementEN: "The arousing. Success. Thunder comes with alarm, then laughter and ease.",
                imageCN: "洊雷，震。君子以恐惧修省。",
                imageEN: "Thunder repeated. The noble person examines themselves with awe and caution."
            ),
            // 52. 艮为山
            Hexagram(
                id: 52, nameCN: "艮为山", nameEN: "Keeping Still", namePinyin: "Gen Wei Shan",
                upperTrigram: "Gen", lowerTrigram: "Gen",
                lines: [false, false, true, false, false, true],
                keywords: ["stillness", "meditation", "restraint", "boundary"],
                coreMeaning: "Mountain upon mountain — profound stillness. When movement ceases, peace arises. Know when to stop and simply be.",
                element: "Earth",
                judgementCN: "艮其背。不获其身。行其庭。不见其人。",
                judgementEN: "Keeping the back still so the body is not felt. Walking in the courtyard without seeing the person.",
                imageCN: "兼山，艮。君子以思不出其位。",
                imageEN: "Mountain upon mountain. The noble person's thoughts do not leave their position."
            ),
            // 53. 风山渐
            Hexagram(
                id: 53, nameCN: "风山渐", nameEN: "Development", namePinyin: "Feng Shan Jian",
                upperTrigram: "Xun", lowerTrigram: "Gen",
                lines: [false, false, true, false, true, true],
                keywords: ["gradual", "development", "patience", "evolution"],
                coreMeaning: "Wind upon the mountain — gradual development. Steady, patient growth like a tree on a mountainside. Trust the natural pace.",
                element: "Wood",
                judgementCN: "渐。女归吉。利贞。",
                judgementEN: "Development. The maiden marries. Favorable perseverance.",
                imageCN: "山上有木，渐。君子以居贤德善俗。",
                imageEN: "Tree on the mountain. The noble person dwells in virtue and improves customs."
            ),
            // 54. 雷泽归妹
            Hexagram(
                id: 54, nameCN: "雷泽归妹", nameEN: "The Marrying Maiden", namePinyin: "Lei Ze Gui Mei",
                upperTrigram: "Zhen", lowerTrigram: "Dui",
                lines: [true, true, false, false, false, true],
                keywords: ["relationship", "commitment", "role", "harmony"],
                coreMeaning: "Thunder over the lake — accepting a role. Sometimes fulfillment comes through embracing your place rather than seeking the spotlight.",
                element: "Wood",
                judgementCN: "归妹。征凶。无攸利。",
                judgementEN: "The marrying maiden. Going forward brings misfortune. Nothing is favorable.",
                imageCN: "泽上有雷，归妹。君子以永终知敝。",
                imageEN: "Thunder over the lake. The noble person considers the end and knows what may go wrong."
            ),
            // 55. 雷火丰
            Hexagram(
                id: 55, nameCN: "雷火丰", nameEN: "Abundance", namePinyin: "Lei Huo Feng",
                upperTrigram: "Zhen", lowerTrigram: "Li",
                lines: [true, false, true, false, false, true],
                keywords: ["abundance", "fullness", "celebration", "generosity"],
                coreMeaning: "Thunder and lightning — peak abundance. Enjoy fullness while it lasts. Share generously, for cycles always turn.",
                element: "Wood",
                judgementCN: "丰。亨。王假之。勿忧。",
                judgementEN: "Abundance. Success. The king attains it. Do not worry.",
                imageCN: "雷电皆至，丰。君子以折狱致刑。",
                imageEN: "Thunder and lightning arrive together. The noble person decides cases with clarity."
            ),
            // 56. 火山旅
            Hexagram(
                id: 56, nameCN: "火山旅", nameEN: "The Wanderer", namePinyin: "Huo Shan Lü",
                upperTrigram: "Li", lowerTrigram: "Gen",
                lines: [false, false, true, false, true, true],
                keywords: ["journey", "wandering", "transition", "adaptation"],
                coreMeaning: "Fire on the mountain — the wanderer's journey. As a traveler in unfamiliar territory, move with grace, humility, and awareness.",
                element: "Fire",
                judgementCN: "旅。小亨。旅贞吉。",
                judgementEN: "The wanderer. Small success. Perseverance on the journey brings fortune.",
                imageCN: "山上有火，旅。君子以明慎用刑而不留狱。",
                imageEN: "Fire on the mountain. The noble person is clear and careful with judgment, not holding grudges."
            ),
            // 57. 巽为风
            Hexagram(
                id: 57, nameCN: "巽为风", nameEN: "The Gentle", namePinyin: "Xun Wei Feng",
                upperTrigram: "Xun", lowerTrigram: "Xun",
                lines: [false, true, true, false, true, true],
                keywords: ["gentleness", "penetration", "influence", "subtlety"],
                coreMeaning: "Wind following wind — gentle penetration. Lasting influence comes not through force but through patient, persistent gentleness.",
                element: "Wood",
                judgementCN: "巽。小亨。利有攸往。利见大人。",
                judgementEN: "The gentle. Small success. Favorable to go forward. Favorable to see the great person.",
                imageCN: "随风，巽。君子以申命行事。",
                imageEN: "Wind following wind. The noble person repeats instructions and carries out their affairs."
            ),
            // 58. 兑为泽
            Hexagram(
                id: 58, nameCN: "兑为泽", nameEN: "The Joyous", namePinyin: "Dui Wei Ze",
                upperTrigram: "Dui", lowerTrigram: "Dui",
                lines: [true, true, false, true, true, false],
                keywords: ["joy", "openness", "exchange", "celebration"],
                coreMeaning: "Lake upon lake — doubled joy. Openness and joyful exchange nourish the spirit. Share your happiness freely.",
                element: "Metal",
                judgementCN: "兑。亨利贞。",
                judgementEN: "The joyous. Success through perseverance.",
                imageCN: "丽泽，兑。君子以朋友讲习。",
                imageEN: "Lakes joined together. The noble person discusses and practices with friends."
            ),
            // 59. 风水涣
            Hexagram(
                id: 59, nameCN: "风水涣", nameEN: "Dispersion", namePinyin: "Feng Shui Huan",
                upperTrigram: "Xun", lowerTrigram: "Kan",
                lines: [false, true, false, false, false, true],
                keywords: ["dispersion", "dissolution", "release", "clarity"],
                coreMeaning: "Wind over water — dissolving what was solid. Let rigid structures dissolve so new clarity can emerge. Release brings renewal.",
                element: "Wood",
                judgementCN: "涣。亨。王假有庙。",
                judgementEN: "Dispersion. Success. The king approaches the temple.",
                imageCN: "风行水上，涣。先王以享于帝立庙。",
                imageEN: "Wind moving over water. The ancient kings made offerings and established temples."
            ),
            // 60. 水泽节
            Hexagram(
                id: 60, nameCN: "水泽节", nameEN: "Limitation", namePinyin: "Shui Ze Jie",
                upperTrigram: "Kan", lowerTrigram: "Dui",
                lines: [true, true, false, false, true, false],
                keywords: ["limitation", "boundary", "measure", "discipline"],
                coreMeaning: "Water above the lake — the power of limitation. Boundaries are not prisons but frames for freedom. Measure brings harmony.",
                element: "Water",
                judgementCN: "节。亨。苦节不可贞。",
                judgementEN: "Limitation. Success. Bitter limitation cannot endure.",
                imageCN: "泽上有水，节。君子以制数度议德行。",
                imageEN: "Water above the lake. The noble person creates measures and discusses virtuous conduct."
            ),
            // 61. 风泽中孚
            Hexagram(
                id: 61, nameCN: "风泽中孚", nameEN: "Inner Truth", namePinyin: "Feng Ze Zhong Fu",
                upperTrigram: "Xun", lowerTrigram: "Dui",
                lines: [true, true, false, false, true, true],
                keywords: ["truth", "sincerity", "trust", "authenticity"],
                coreMeaning: "Wind over the lake — inner truth resonating outward. When you speak from sincere conviction, even the hardest hearts can be moved.",
                element: "Wood",
                judgementCN: "中孚。豚鱼吉。利涉大川。",
                judgementEN: "Inner truth. Even pigs and fish are moved. Favorable to cross the great water.",
                imageCN: "泽上有风，中孚。君子以议狱缓死。",
                imageEN: "Wind over the lake. The noble person deliberates on judgments and delays executions."
            ),
            // 62. 雷山小过
            Hexagram(
                id: 62, nameCN: "雷山小过", nameEN: "Small Excess", namePinyin: "Lei Shan Xiao Guo",
                upperTrigram: "Zhen", lowerTrigram: "Gen",
                lines: [false, false, true, false, false, true],
                keywords: ["small excess", "caution", "adaptation", "humility"],
                coreMeaning: "Thunder on the mountain — small things in excess. In small matters, go beyond. In great matters, stay within bounds.",
                element: "Wood",
                judgementCN: "小过。亨利贞。可小事不可大事。",
                judgementEN: "Small excess. Success through perseverance. Small matters are favorable; great matters are not.",
                imageCN: "山上有雷，小过。君子以行过乎恭。",
                imageEN: "Thunder on the mountain. The noble person exceeds in courtesy."
            ),
            // 63. 水火既济
            Hexagram(
                id: 63, nameCN: "水火既济", nameEN: "After Completion", namePinyin: "Shui Huo Ji Ji",
                upperTrigram: "Kan", lowerTrigram: "Li",
                lines: [true, false, true, false, true, false],
                keywords: ["completion", "achievement", "order", "vigilance"],
                coreMeaning: "Water over fire — all things in their proper place. Completion achieved. Yet stay vigilant, for order tends toward disorder.",
                element: "Water",
                judgementCN: "既济。亨小。利贞。初吉终乱。",
                judgementEN: "After completion. Small success. Favorable perseverance. Good at first, disorder at the end.",
                imageCN: "水在火上，既济。君子以思患而豫防之。",
                imageEN: "Water over fire. The noble person anticipates danger and prepares against it."
            ),
            // 64. 火水未济
            Hexagram(
                id: 64, nameCN: "火水未济", nameEN: "Before Completion", namePinyin: "Huo Shui Wei Ji",
                upperTrigram: "Li", lowerTrigram: "Kan",
                lines: [false, true, false, true, false, true],
                keywords: ["incompletion", "potential", "transition", "hope"],
                coreMeaning: "Fire over water — before completion. The final hexagram reminds us: every ending is a new beginning. The journey continues.",
                element: "Fire",
                judgementCN: "未济。亨。小狐汔济濡其尾。",
                judgementEN: "Before completion. Success. The young fox nearly crosses but wets its tail.",
                imageCN: "火在水上，未济。君子以慎辨物居方。",
                imageEN: "Fire over water. The noble person carefully distinguishes things and places them where they belong."
            ),
        ]
    }
}
