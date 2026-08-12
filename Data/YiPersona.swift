import Foundation

/// Yi 的人格外显层：集中管理嗓音常量与按卦象的洞察（签名金句 + 今日之时短语）。
///
/// 设计意图：
/// - 引导页、对话开场、分享卡、今日反思叙事都从这里取声，确保「人格一致、辨识度高」。
/// - 签名金句短、有态度、可被截图传播（借 Co-Star「品牌嗓音即内容」机制，但保留离线）。
/// - 今日之时短语把卦象翻译成「当下阶段」的反思语言，而非预测，契合 App Store 规避策略。
enum YiPersona {
    /// 开场白（引导页复用）
    static let openingLine = "I'm Yi, not a fortune teller, but a companion who helps you see your life with fresh eyes."

    /// 口头禅（人格锚点，反复出现强化辨识度）
    static let catchphrase = "I don't predict the future. I hold up a mirror to the present."

    /// 对话首句（ChatView 空态时展示）
    static let chatGreeting = "Tell me what's stirring in your heart, and we'll see what the moment reveals."

    /// 按卦象返回（签名金句, 今日之时短语）
    static func insight(forHexagramID id: Int) -> (signature: String, phase: String) {
        if let v = insightMap[id] { return v }
        return fallback[(id - 1) % fallback.count]
    }

    /// 64 卦：每卦一句 Yi 嗓音签名 + 一个「当下阶段」短语
    private static let insightMap: [Int: (signature: String, phase: String)] = [
        1:  ("You were built to begin. The sky doesn't ask permission.", "begin before you're ready"),
        2:  ("Strength wears soft clothes. Let things arrive.", "receive what comes"),
        3:  ("Every forest starts as a tangled seed. Begin anyway.", "begin inside the mess"),
        4:  ("Not knowing is the first step of learning. Stay curious.", "stay teachable"),
        5:  ("Patience isn't pause. It's the river finding the sea.", "wait with trust"),
        6:  ("Pick your storms. Some arguments aren't yours to win.", "choose your conflicts"),
        7:  ("Discipline is love in action. Lead with calm.", "lead with order"),
        8:  ("Belonging is chosen, not found. Reach toward your people.", "reach toward others"),
        9:  ("Small wins gather. The wind builds the cloud.", "gather small wins"),
        10: ("Walk carefully, and the tiger won't bite. Proceed with respect.", "proceed with care"),
        11: ("Good moments are gardens. Tend them while they bloom.", "tend what's good"),
        12: ("When the world clogs, turn inward and wait for the thaw.", "turn inward"),
        13: ("Common ground is everywhere if you lower your flag.", "find common ground"),
        14: ("Abundance is a guest. Share it and it stays.", "share your surplus"),
        15: ("The mountain hides in the valley. Quiet greatness lasts.", "stay humble"),
        16: ("Joy is fuel. Let it move you, don't perform it.", "let joy move you"),
        17: ("Flow with what's true. Follow, don't chase.", "follow what's true"),
        18: ("Repair the inherited mess. You are the fixer.", "repair what's broken"),
        19: ("Something good approaches. Step toward it with care.", "approach with care"),
        20: ("Step back and watch. The view teaches what the push can't.", "observe first"),
        21: ("Some knots need teeth. Address what blocks you.", "bite through blocks"),
        22: ("Beauty is meaning made visible. Adorn what matters.", "add grace"),
        23: ("Let the rotten fall. Clear ground for what's next.", "let go what's dead"),
        24: ("Every ending loops back to a beginning. Come home to yourself.", "return to yourself"),
        25: ("Act without agenda. The unexpected becomes your ally.", "act without agenda"),
        26: ("Gather power slowly. The mountain stores the storm.", "store your strength"),
        27: ("Feed what truly feeds you. Guard your mouth and mind.", "nourish wisely"),
        28: ("Bold times call for bold structure. Don't shrink.", "stand in boldness"),
        29: ("You've crossed deep water before. Breathe, and cross again.", "cross with breath"),
        30: ("Clarity needs a wick. What are you devoted to?", "find your devotion"),
        31: ("Attraction is silent. Let it move before you name it.", "let influence move"),
        32: ("Steady beats spectacular. Keep the long rhythm.", "keep the rhythm"),
        33: ("Knowing when to leave is its own courage. Step back.", "know when to leave"),
        34: ("Power without restraint breaks its own house. Use it lightly.", "use power lightly"),
        35: ("Rise like the sun, modest and sure. Recognition follows.", "rise with steadiness"),
        36: ("Shine inward when the world dims. Protect your flame.", "protect your light"),
        37: ("Order at home is order everywhere. Start there.", "begin at home"),
        38: ("Differences aren't distance. Find the thread between.", "bridge the difference"),
        39: ("When the path breaks, rest and reroute. Don't force the cliff.", "rest and reroute"),
        40: ("The knot loosens. Breathe out what you've held.", "release the tension"),
        41: ("Release what weighs you. Less can be the door.", "release the excess"),
        42: ("Give, and you grow. Benefit flows through open hands.", "give to grow"),
        43: ("Decisive moments favor the clear voice. Speak, then act.", "decide and act"),
        44: ("Unexpected encounters arrive. Receive them with eyes open.", "receive the unexpected"),
        45: ("Gather your people and your purpose. Community is medicine.", "gather together"),
        46: ("Growth is quiet soil work. Keep ascending.", "keep ascending"),
        47: ("Constraints cage the body, not the mind. Find the small freedom.", "find small freedom"),
        48: ("Refresh what's gone stale. Your depth is renewable.", "refresh your depth"),
        49: ("Shed the old skin when it no longer fits. Transform.", "shed the old"),
        50: ("You are the vessel remaking the meal. Nourish anew.", "renew what's sacred"),
        51: ("The shock awakens. Let it clarify, not terrify.", "let the shock clarify"),
        52: ("Stop at the right moment. Stillness is its own answer.", "be still"),
        53: ("Real things ripen in order. Don't rush the branch.", "ripen in order"),
        54: ("Right order matters. Don't trade the future for the now.", "honor the order"),
        55: ("Peak moments are brief. Stand fully in the light while it lasts.", "stand in the light"),
        56: ("Travel light, observe much. Home is a state, not a place.", "travel light"),
        57: ("Persuasion is soft and persistent. The wind wears the stone.", "persist softly"),
        58: ("Open, glad, and real. Let joy be spoken.", "speak your joy"),
        59: ("What scatters can be gathered anew. Dissolve the blockage.", "dissolve and regather"),
        60: ("A boundary is a kindness. Know your measure.", "keep your measure"),
        61: ("Sincerity needs no proof. Be true and the trust arrives.", "be sincerely true"),
        62: ("Small deviations are allowed. Don't overreach the moment.", "stay within bounds"),
        63: ("Done is a pause, not a stop. Tend what's finished.", "tend what's done"),
        64: ("The journey loops. The unfinished is where life lives.", "live the unfinished")
    ]

    /// 兜底池（id 越界时用，确定性选取）
    private static let fallback: [(signature: String, phase: String)] = [
        ("The moment is speaking. Lean in and listen.", "lean in and listen"),
        ("Something is shifting. Notice what.", "notice the shift"),
        ("You already know more than you think. Trust it.", "trust what you know")
    ]
}
