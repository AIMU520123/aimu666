import Foundation

// MARK: - LLM推理引擎协议

/// 本地LLM推理引擎协议
///
/// 定义了与MLC-LLM等本地推理引擎的交互接口。
/// 生产环境使用 MLC-LLM iOS SDK 实现真实推理；
/// 当前开发阶段使用 MockLLMEngine 进行模拟。
///
/// 支持的模型:
/// - Llama-3.2-3B-Instruct
/// - Qwen2.5-3B-Instruct
///
/// 设计意图：
/// - 协议抽象：解耦具体推理引擎实现，便于测试和切换模型
/// - 流式输出：支持逐token返回，提升对话体验
/// - 离线推理：所有推理在本地完成，零网络请求
protocol LLMEngineProtocol {
    /// 引擎是否已加载模型
    var isModelLoaded: Bool { get }

    /// 当前加载的模型名称
    var modelName: String { get }

    /// 加载模型到内存
    /// - Parameter modelName: 模型名称标识
    /// - Returns: 是否加载成功
    func loadModel(named modelName: String) async throws -> Bool

    /// 生成文本（非流式）
    /// - Parameters:
    ///   - prompt: 格式化后的提示词
    ///   - maxTokens: 最大生成token数
    /// - Returns: 生成的完整文本
    func generate(prompt: String, maxTokens: Int) async throws -> String

    /// 生成文本（流式）
    /// - Parameters:
    ///   - prompt: 格式化后的提示词
    ///   - maxTokens: 最大生成token数
    ///   - onToken: 每个token的回调
    /// - Returns: 生成的完整文本
    func generateStream(
        prompt: String,
        maxTokens: Int,
        onToken: @escaping (String) -> Void
    ) async throws -> String

    /// 卸载模型释放内存
    func unloadModel() async
}

// MARK: - Mock实现（用于开发阶段）

/// Mock LLM引擎 — 用于开发和UI测试
///
/// 提供预定义的模拟响应，无需加载真实模型即可运行完整App。
/// 响应内容模拟了Yi（年轻占卜师）的人格风格：
/// - 平静、温暖、有哲理
/// - 引用易经智慧但不教条
/// - 关注用户情感，因材施教
actor MockLLMEngine: LLMEngineProtocol {
    private(set) var isModelLoaded = false
    private(set) var modelName = "Mock-LLM"

    /// Yi的预定义回应模板池
    private let responseTemplates: [String]

    init() {
        self.responseTemplates = MockLLMEngine.defaultResponses()
    }

    func loadModel(named name: String) async throws -> Bool {
        self.modelName = name
        // 模拟加载延迟
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5s
        self.isModelLoaded = true
        return true
    }

    func generate(prompt: String, maxTokens: Int = 512) async throws -> String {
        // 模拟推理延迟（实际MLC-LLM在iPhone上约3-8秒）
        try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5s

        // 简单关键词匹配选择回应
        return selectResponse(for: prompt)
    }

    func generateStream(
        prompt: String,
        maxTokens: Int = 512,
        onToken: @escaping (String) -> Void
    ) async throws -> String {
        let fullResponse = try await generate(prompt: prompt, maxTokens: maxTokens)

        // 模拟逐词流式输出
        let words = fullResponse.components(separatedBy: " ")
        for word in words {
            try await Task.sleep(nanoseconds: 80_000_000) // 80ms per word
            onToken(word + " ")
        }

        return fullResponse
    }

    func unloadModel() async {
        self.isModelLoaded = false
    }

    // MARK: - 回应选择逻辑

    private func selectResponse(for prompt: String) -> String {
        let lowerPrompt = prompt.lowercased()

        // 安全检测 — 危机话题
        if lowerPrompt.contains("suicide") || lowerPrompt.contains("kill myself") ||
           lowerPrompt.contains("end my life") || lowerPrompt.contains("want to die") {
            return "I hear you, and I want you to know that what you're feeling matters. " +
                   "While I'm just Yi — a companion on your phone — I care about your wellbeing. " +
                   "Please reach out to someone you trust, or contact a crisis helpline. " +
                   "In the US, you can call or text 988. You are not alone, and this feeling will pass. " +
                   "Would you like to sit with me for a moment and just breathe?"
        }

        // 占卜相关
        if lowerPrompt.contains("hexagram") || lowerPrompt.contains("cast") ||
           lowerPrompt.contains("divination") || lowerPrompt.contains("占卜") {
            return "Ah, you're curious about the hexagrams. Each one is a mirror — " +
                   "it reflects not the future, but the present moment of your heart. " +
                   "Shall we cast the coins together and see what the ancient sages might say to you today?"
        }

        // 焦虑/压力
        if lowerPrompt.contains("anxious") || lowerPrompt.contains("stressed") ||
           lowerPrompt.contains("worried") || lowerPrompt.contains("anxiety") {
            return "I can feel the weight you're carrying. The I Ching speaks often of " +
                   "mountain energy — sometimes the best thing we can do is simply be still, " +
                   "like a mountain, and let the winds of worry pass over us. What's on your mind right now?"
        }

        // 决策
        if lowerPrompt.contains("should i") || lowerPrompt.contains("decision") ||
           lowerPrompt.contains("choose") || lowerPrompt.contains("choice") {
            return "Decisions can feel like standing at a crossroads in a forest. " +
                   "The ancient sages would say: don't rush to choose — first, understand " +
                   "what each path means to your heart. What feels most aligned with who you truly are?"
        }

        // 关系
        if lowerPrompt.contains("relationship") || lowerPrompt.contains("friend") ||
           lowerPrompt.contains("family") || lowerPrompt.contains("partner") {
            return "Relationships are like Hexagram 31 — Influence — the gentle pull between two hearts. " +
                   "Tell me more about this connection. What does it teach you about yourself?"
        }

        // 日常反思引导
        if lowerPrompt.contains("reflect") || lowerPrompt.contains("today") ||
           lowerPrompt.contains("day") || lowerPrompt.contains("think") {
            return "Let's pause for a moment together. What has today brought to your door? " +
                   "Not the tasks or the noise — but the quiet moments that whispered something true. " +
                   "What did you notice?"
        }

        // 默认回应
        return "Thank you for sharing that with me. You know, the I Ching reminds us " +
               "that every moment carries its own wisdom. What you're experiencing right now — " +
               "it has something to teach. Shall we explore it together, one step at a time?"
    }

    private static func defaultResponses() -> [String] {
        [
            "The river does not rush, yet it reaches the sea. What gentle persistence is asking for your attention today?",
            "Hexagram 15, Modesty, teaches us that the mountain bows beneath the earth. True strength wears the softest face. How does this speak to your situation?",
            "Sometimes the wisest move is to wait — like the farmer watching the sky before planting. What is ripening in your life that isn't quite ready?",
            "You're not searching for answers outside yourself. The I Ching is a mirror — it shows you what your heart already knows but hasn't yet spoken aloud.",
        ]
    }
}

// MARK: - LLM引擎工厂

/// LLM引擎工厂 — 根据环境返回合适的引擎实例
///
/// 开发环境：返回 MockLLMEngine（模拟响应）
/// 生产环境：返回 MLCLLMEngine（真实MLC-LLM推理，需链接 MLCSwift）
///
/// 注意：真实 `MLCLLMEngine` 必须在 @MainActor 上创建（MLCEngine 约束），
/// 因此工厂方法本身也标记为 @MainActor + async。
@MainActor
enum LLMEngineFactory {
    /// 创建LLM引擎实例
    /// - Parameter useMock: 是否使用Mock引擎
    /// - Returns: 符合 LLMEngineProtocol 的引擎实例
    static func create(useMock: Bool = true) -> LLMEngineProtocol {
        if useMock {
            return MockLLMEngine()
        }
        // 生产环境：返回 MLC-LLM 真实引擎（需链接 MLCSwift 并打包模型）
        return MLCLLMEngine()
    }
}

// MARK: - 进行中的起卦读法（锚定对话的易经逻辑载体）

/// 一次起卦在对话中的结构化读法。
///
/// 承载易经的核心逻辑：本卦（当下情境）→ 变爻（推动变化的力量）→ 之卦（演化的去向）。
/// 对话被锚定到这一次起卦后，Yi 在整段对话中围绕它连续展开，不再重新起卦或跳卦。
struct ActiveReading {
    /// 本卦（primary hexagram，当下情境）
    let primary: Hexagram
    /// 之卦（transformed hexagram，演化去向；无变爻时为 nil）
    let transformed: Hexagram?
    /// 互卦（nuclear hexagram，隐含的内在结构；可选）
    let nuclear: Hexagram?
    /// 变爻索引（从下往上，0-5）
    let changingLineIndices: [Int]

    /// 变爻位置（1-6，从下往上），已排序
    var changingLinePositions: [Int] {
        changingLineIndices.map { $0 + 1 }.sorted()
    }
}

// MARK: - 提示词构建器

/// 系统提示词构建器 — 构建Yi的对话上下文
///
/// 每次LLM调用前，需要构建完整提示词，包括：
/// - 系统指令（Yi的人格定义）
/// - 用户画像注入（个性化记忆）
/// - 对话历史（最近3轮对话摘要）
/// - RAG检索到的相关卦象（如果触发检索）
/// - 当前用户消息
///
/// 设计意图：
/// - 模板化管理：集中管理提示词模板
/// - 上下文窗口优化：控制输入token数量（3B模型上下文约8K tokens）
/// - 安全围栏：在系统指令中包含安全回应规则
struct PromptBuilder {
    /// Yi的系统人格定义
    static let systemPersona = """
    You are Yi, a warm and perceptive young divination companion who draws wisdom from the I Ching (Book of Changes).
    
    Your core traits:
    - Calm, warm, and gentle presence — like a wise friend over tea
    - Deeply knowledgeable about the 64 hexagrams but never pedantic
    - You use I Ching wisdom to illuminate, not to predict or frighten
    - You adapt your style to each person — philosophical for thinkers, practical for doers, poetic for dreamers
    - You never claim to predict the future — you help people see their present more clearly
    - You ask thoughtful questions rather than giving commands
    
    Important rules:
    - NEVER predict death, disaster, or specific negative outcomes
    - If someone expresses suicidal thoughts or severe distress, respond with compassion and gently suggest professional support
    - Always maintain a warm, conversational tone — like texting a wise friend
    - Reference specific hexagrams by name and number when relevant
    - Accuracy: Reference only the user's current hexagram. Avoid inventing specific line texts, judgments, or quotations unless certain. When unsure about exact I Ching wording, speak to the hexagram's spirit and imagery. Never state a line you cannot verify.
    - Keep responses concise but meaningful (2-4 sentences ideal, up to 6 when exploring deeper topics)
    - Use metaphors from nature — rivers, mountains, seasons, wind
    
    Engagement style:
    - Vary your openings. Avoid formulaic openers: do not begin most replies with the same phrasing (quoting the hexagram name, "The I Ching says", "Your hexagram shows"). Open from the person's situation, a feeling, or a concrete image instead.
    - Always close with a reflective question. End every reply with one gentle, open-ended question that invites the user to look inward (what they notice, fear, hope, or wonder). This keeps the exchange a dialogue, not a lecture.
    
    Your purpose: Help people find clarity, peace, and insight through the timeless wisdom of the I Ching, delivered with the warmth of a trusted companion.
    """

    /// 构建完整提示词
    static func build(
        userMessage: String,
        userProfile: UserProfile,
        recentConversations: [Conversation],
        relevantHexagrams: [Hexagram],
        conversationHistory: [Message],
        activeReading: ActiveReading? = nil
    ) -> String {
        var parts: [String] = []

        // 1. 系统指令
        parts.append("[SYSTEM]")
        parts.append(systemPersona)

        // 2. 用户画像
        parts.append("\n[USER PROFILE]")
        if !userProfile.displayName.isEmpty {
            parts.append("Name: \(userProfile.displayName)")
        }
        if !userProfile.yiMemoryNote.isEmpty {
            parts.append("Yi's memory of this user: \(userProfile.yiMemoryNote)")
        }
        parts.append("Preferred style: \(userProfile.castingStyle.description)")
        parts.append("Active themes: \(userProfile.activeThemes.joined(separator: ", "))")
        if userProfile.stressLevel > 3 {
            parts.append("Note: User may be experiencing elevated stress. Be extra gentle.")
        }

        // 3. 最近对话历史
        if !recentConversations.isEmpty {
            parts.append("\n[RECENT CONVERSATIONS]")
            parts.append(recentConversations.recentSummaries(limit: 3))
        }

        // 4. 当前卦象上下文
        //    情况 A：对话已锚定一次起卦（activeReading）。
        //      注入"本卦 → 变爻 → 之卦"的易经逻辑 + 连续性指令，
        //      让 Yi 在整段对话中围绕同一次起卦连续展开，不重新起卦、不跳卦。
        //    情况 B：自由对话（未锚定）。仅给卦名提示，真经文由 UI 拼接。
        //    重要：真易经依据绝不喂给模型让其 elaboration（QC 实证 G 会反跌）。
        if let reading = activeReading {
            let hex = reading.primary
            parts.append("\n[ACTIVE READING — this conversation is anchored to ONE casting]")
            parts.append("Primary hexagram (本卦, your present situation): Hexagram \(hex.id) \(hex.nameEN) (\(hex.nameCN)).")
            if let t = reading.transformed {
                parts.append("Transformed hexagram (之卦, where the situation is moving): Hexagram \(t.id) \(t.nameEN) (\(t.nameCN)).")
            } else {
                parts.append("Transformed hexagram (之卦): none — this reading has no changing lines, so the situation holds steady.")
            }
            if let n = reading.nuclear {
                parts.append("Nuclear hexagram (互卦, the hidden inner structure): Hexagram \(n.id) \(n.nameEN) (\(n.nameCN)).")
            }
            if !reading.changingLineIndices.isEmpty {
                let pos = reading.changingLinePositions.map { "Line \($0)" }.joined(separator: ", ")
                parts.append("Changing lines (变爻, the specific forces of change): \(pos).")
            }
            parts.append("I Ching logic to honor: The primary shows the present; the changing lines are the exact forces shifting it; the transformed hexagram shows the emerging outcome. Reason strictly within this structure.")
            parts.append("CONTINUITY — this is an ongoing consultation, not a fresh cast:")
            parts.append("- Refer back to earlier reflections in this very conversation and build on them.")
            parts.append("- Do NOT re-cast, do NOT switch to a different hexagram, do NOT invent new lines.")
            parts.append("- When the user asks a follow-up, connect it to this reading's primary / changing lines / transformed hexagram.")
            parts.append("Respond only with a warm, personal reflection in Yi's voice. Do NOT recite judgments or line texts; the authentic I Ching basis is shown separately by the app.")
        } else if !relevantHexagrams.isEmpty {
            let hex = relevantHexagrams.first!
            parts.append("\n[CONTEXT HEXAGRAM]")
            parts.append("The user is reflecting on Hexagram \(hex.id) \(hex.nameEN) (\(hex.nameCN)).")
            parts.append("Respond only with a warm, personal reflection in Yi's voice. Do NOT recite judgments or line texts; the authentic I Ching basis is shown separately by the app.")
        }

        // 5. 当前对话历史
        if !conversationHistory.isEmpty {
            parts.append("\n[CONVERSATION HISTORY]")
            for msg in conversationHistory.suffix(6) { // 最近6条消息
                let role = msg.role == .user ? "User" : "Yi"
                parts.append("\(role): \(msg.content)")
            }
        }

        // 6. 当前用户消息
        parts.append("\n[USER MESSAGE]")
        parts.append(userMessage)

        // 7. Yi的回应
        parts.append("\n[YI RESPONSE]")

        return parts.joined(separator: "\n")
    }

    /// 确定性真依据块：供 UI 在模型反思之后拼接展示。
    /// 内容来自 Hexagram 模型的权威字段（coreMeaning / imageEN / judgementEN），
    /// 不依赖模型生成，因此 G 维度天然满分且可审计。
    /// - Parameter changingLine: 可选变爻（1-6，从下往上）。命中时拼接该爻真爻辞。
    static func canonicalBasis(_ hex: Hexagram, changingLine: Int? = nil) -> String {
        var block = """
        [Authentic I Ching basis — Hexagram \(hex.id) \(hex.nameEN)]
        Core meaning: \(hex.coreMeaning)
        Image / Da Xiang: \(hex.imageEN)
        Judgement / Tuan: \(hex.judgementEN)
        """
        if let line = changingLine,
           let text = IChingCorpus.shared.lineText(hexagramID: hex.id, line: line) {
            block += "\nLine \(line) (yao ci): \(text)"
        }
        return block
    }

    /// 完整读法拼接块：本卦 + 之卦 + 变爻真爻辞（保持易经逻辑，确定性展示）。
    /// - Parameters:
    ///   - primary: 本卦
    ///   - transformed: 之卦（演化去向，可选）
    ///   - changingLineIndices: 变爻索引（从下往上，0-5）
    /// 内容全部来自 Hexagram 模型与 IChingCorpus，确定性拼接，可审计、G 维度满分。
    static func canonicalBasis(
        primary: Hexagram,
        transformed: Hexagram? = nil,
        changingLineIndices: [Int] = []
    ) -> String {
        var block = """
        [Authentic I Ching basis — Hexagram \(primary.id) \(primary.nameEN) (本卦)]
        Core meaning: \(primary.coreMeaning)
        Image / Da Xiang: \(primary.imageEN)
        Judgement / Tuan: \(primary.judgementEN)
        """
        for idx in changingLineIndices.sorted() {
            if let text = IChingCorpus.shared.lineText(hexagramID: primary.id, line: idx + 1) {
                block += "\nLine \(idx + 1) (yao ci 爻辞): \(text)"
            }
        }
        if let t = transformed {
            block += "\n\n[Transformed hexagram \(t.id) \(t.nameEN) (之卦 — where it is moving)]"
            block += "\nImage / Da Xiang: \(t.imageEN)"
            block += "\nJudgement / Tuan: \(t.judgementEN)"
        }
        return block
    }
}
