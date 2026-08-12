import SwiftUI

/// 与Yi的对话界面
///
/// 类似 iMessage 风格的消息气泡对话。
/// 使用本地LLM推理 + RAG检索来生成Yi的回应。
///
/// 功能特性：
/// 1. 消息气泡UI（用户=强调色/Yi=浅底）
/// 2. 流式文本输出（本地模型 token-by-token 生成）
/// 3. 记忆注入（加载用户画像 + 最近3轮对话）
/// 4. 卦象引用（对话中提及卦象时显示卦象卡片）
/// 5. 安全兜底（检测危机话题时显示安全提示）
/// 6. 自动滚动到最新消息
///
/// 设计意图：
/// - 对话是Yi与用户的"情感连接"核心载体
/// - 引擎通过 `ModelManager.shared` 注入，设备有真实模型时自动启用，
///   开发期回落 Mock，避免每个 View 重复占内存（评审 P0-2）
struct ChatView: View {
    @Binding var userProfile: UserProfile

    /// 进入对话时锚定的起卦结果（可选）。
    /// 非空时，本段对话围绕这一次起卦连续展开，保持"本卦 → 变爻 → 之卦"的易经逻辑。
    var initialCasting: CastingResult? = nil

    @Environment(\.dismiss) var dismiss
    @Environment(\.appTheme) var theme

    /// 当前对话
    @State private var conversation = Conversation()

    /// 输入文本
    @State private var inputText = ""

    /// 是否正在生成回应
    @State private var isGenerating = false

    /// 流式输出缓冲
    @State private var streamingText = ""

    /// 错误消息
    @State private var errorMessage: String?

    /// 相关卦象推荐
    @State private var relevantHexagrams: [Hexagram] = []

    /// 滚动视图代理
    @Namespace private var scrollNamespace

    /// 服务实例（共享单例引擎，避免重复加载模型）
    private let modelManager = ModelManager.shared
    private let ragService: RAGServiceProtocol = RAGServiceFactory.create()
    private let memoryService = MemoryService.shared
    private let privacyService = PrivacyService.shared

    var body: some View {
        VStack(spacing: 0) {
            // 聊天消息列表
            ScrollViewReader { scrollProxy in
                ScrollView {
                LazyVStack(spacing: 12) {
                    // 进行中的读法横幅（锚定起卦时显示，保持易经逻辑连续性）
                    if conversation.activeCasting != nil {
                        activeReadingBanner
                    }

                    // 欢迎消息
                    welcomeMessage

                        // 对话消息
                        ForEach(conversation.messages) { message in
                            MessageBubbleView(
                                message: message,
                                theme: theme,
                                relevantHexagrams: relevantHexagrams
                            )
                            .id(message.id)
                        }

                        // 流式输出
                        if isGenerating && !streamingText.isEmpty {
                            StreamingBubbleView(text: streamingText, theme: theme)
                                .id("streaming")
                        }

                        // 卦象推荐
                        if !relevantHexagrams.isEmpty && !isGenerating {
                            relatedHexagramsView
                                .id("related")
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .background(theme.palette.backgroundGradient)
                .onChange(of: conversation.messages.count) { _, _ in
                    scrollToBottom(proxy: scrollProxy)
                }
                .onChange(of: streamingText) { _, _ in
                    scrollToBottom(proxy: scrollProxy)
                }
                .onChange(of: relevantHexagrams.count) { _, _ in
                    scrollToBottom(proxy: scrollProxy)
                }
            }

            // 安全提示栏
            if let error = errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
            }

            // 输入区域
            inputArea
        }
        .navigationTitle("Yi")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
            if conversation.activeCasting != nil {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        // 结束本次读法，回到自由对话（不再锚定起卦）
                        conversation.activeCasting = nil
                        relevantHexagrams = []
                    } label: {
                        Label("End reading", systemImage: "xmark.circle")
                    }
                }
            }
        }
        .task {
            if let initialCasting {
                // 锚定：整段对话围绕这一次起卦连续展开
                conversation.activeCasting = ActiveCastingAnchor(from: initialCasting)
                conversation.hexagramID = initialCasting.primaryHexagramID
            } else if let lastConversation = try? DatabaseManager.shared.loadAllConversations().first {
                conversation = lastConversation
            }
        }
    }

    // MARK: - 欢迎消息

    private var welcomeMessage: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Yi")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(theme.palette.ink)

                Text(greetingForUser)
                    .font(.body)
                    .foregroundColor(.primary)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(theme.palette.ink.opacity(0.06))
                    )
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 40)
        }
        .padding(.top, 8)
    }

    private var greetingForUser: String {
        if userProfile.isNewUser {
            return "Hi! I'm Yi. I don't know much about you yet, but I'm looking forward to our journey together. What's on your mind today?"
        }
        let name = userProfile.displayName.isEmpty ? "there" : userProfile.displayName
        return "Welcome back, \(name). I've been looking forward to our conversation. How are you feeling today?"
    }

    // MARK: - 输入区域

    private var inputArea: some View {
        VStack(spacing: 0) {
            Divider()
                .background(theme.palette.ink.opacity(0.1))

            HStack(spacing: 12) {
                TextField("Share your thoughts...", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(theme.palette.ink.opacity(0.06))
                    )
                    .lineLimit(1...4)
                    .disabled(isGenerating)

                Button {
                    sendMessage()
                } label: {
                    Image(systemName: isGenerating ?
                          "stop.circle.fill" : "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(
                            inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? theme.palette.ink.opacity(0.3)
                            : theme.palette.ink
                        )
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isGenerating)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(.regularMaterial)
    }

    // MARK: - 相关卦象视图

    private var relatedHexagramsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Related Hexagrams")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 8)

            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(relevantHexagrams.prefix(3)) { hex in
                        NavigationLink {
                            HexagramDetailView(hexagram: hex, userProfile: $userProfile)
                        } label: {
                            VStack(spacing: 4) {
                                Text(hex.symbol)
                                    .font(.system(size: 32))
                                Text(hex.nameEN)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - 对话逻辑

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isGenerating else { return }

        // 安全检查
        let safetyCheck = privacyService.checkSafetyConcern(in: text)
        if case .crisisDetected = safetyCheck {
            let userMessage = Message(role: .user, content: text)
            conversation.messages.append(userMessage)

            let safetyMessage = Message(
                role: .yi,
                content: safetyResponse,
                isSafetyNotice: true
            )
            conversation.messages.append(safetyMessage)

            inputText = ""
            return
        }

        let userMessage = Message(role: .user, content: text)
        conversation.messages.append(userMessage)
        inputText = ""

        memoryService.updateProfileFromMessage(
            profile: &userProfile, userMessage: text
        )

        generateResponse(to: text)
    }

    private func generateResponse(to message: String) {
        isGenerating = true
        streamingText = ""
        relevantHexagrams = []

        // 锚定读法：从对话的 activeCasting 构造 ActiveReading（同步，无需异步）
        let activeReading: ActiveReading? = {
            guard let cr = conversation.activeCasting,
                  let primary = HexagramDataStore.shared.hexagram(byID: cr.primaryHexagramID) else {
                return nil
            }
            let transformed = cr.transformedHexagramID.flatMap { HexagramDataStore.shared.hexagram(byID: $0) }
            let nuclear = HexagramDataStore.shared.hexagram(byID: cr.nuclearHexagramID)
            return ActiveReading(
                primary: primary,
                transformed: transformed,
                nuclear: nuclear,
                changingLineIndices: cr.changingLineIndices
            )
        }()

        Task {
            do {
                // 上下文卦象：锚定读法时恒为本卦（保持连续性，不随 RAG 漂移）；
                // 自由对话时按 RAG 检索相关卦象。
                let contextHexagrams: [Hexagram]
                if activeReading != nil {
                    contextHexagrams = [activeReading!.primary]
                } else {
                    let ragResults = try await ragService.retrieveRelevantHexagrams(
                        query: message, topK: 3
                    )
                    contextHexagrams = ragResults.compactMap {
                        HexagramDataStore.shared.hexagram(byID: $0.hexagramID)
                    }
                }

                await MainActor.run {
                    relevantHexagrams = contextHexagrams
                }

                let recentConversations = (try? DatabaseManager.shared.loadAllConversations()) ?? []

                let prompt = PromptBuilder.build(
                    userMessage: message,
                    userProfile: userProfile,
                    recentConversations: recentConversations,
                    relevantHexagrams: contextHexagrams,
                    conversationHistory: conversation.messages,
                    activeReading: activeReading
                )

                // 调用共享引擎生成（设备有真实模型时用 MLC，否则 Mock 回落）
                let response = try await modelManager.generateStream(
                    prompt: prompt,
                    maxTokens: 256,
                    onToken: { token in
                        Task { @MainActor in
                            streamingText += token
                        }
                    }
                )

                await MainActor.run {
                    let yiMessage = Message(
                        role: .yi,
                        content: response,
                        attachedHexagramID: contextHexagrams.first?.id
                    )
                    conversation.messages.append(yiMessage)
                    conversation.lastActiveAt = Date()
                    streamingText = ""
                    isGenerating = false
                }

                try? DatabaseManager.shared.saveConversation(conversation)

            } catch {
                await MainActor.run {
                    errorMessage = "I need a moment to reflect. Let me try again."
                    isGenerating = false
                    streamingText = ""
                }

                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await MainActor.run {
                    errorMessage = nil
                }
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let lastMessage = conversation.messages.last {
            withAnimation {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        } else if isGenerating {
            withAnimation {
                proxy.scrollTo("streaming", anchor: .bottom)
            }
        }

        if !relevantHexagrams.isEmpty {
            withAnimation {
                proxy.scrollTo("related", anchor: .bottom)
            }
        }
    }

    private var safetyResponse: String {
        "I hear you, and I want you to know that what you're feeling matters deeply. " +
        "I'm just Yi — a companion on your phone — but I care about your wellbeing. " +
        "Please reach out to someone you trust or contact a crisis helpline. " +
        "In the United States, you can call or text 988. You are not alone. " +
        "Would you like to sit with me for a moment and just breathe?"
    }
}

// MARK: - 消息气泡视图

/// 单条消息的气泡视图
struct MessageBubbleView: View {
    let message: Message
    let theme: AppTheme
    let relevantHexagrams: [Hexagram]

    var body: some View {
        HStack(alignment: .top) {
            if message.role == .user {
                Spacer(minLength: 40)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                if message.role != .user {
                    Text(message.role.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                }

                Text(message.content)
                    .font(.body)
                    .foregroundColor(message.role == .user ? theme.palette.textOnAccent : .primary)
                    .padding(12)
                    .background(bubbleBackground)
                    .fixedSize(horizontal: false, vertical: true)

                if message.isSafetyNotice {
                    Label("Support Available", systemImage: "heart.fill")
                        .font(.caption2)
                        .foregroundColor(.red.opacity(0.7))
                }

                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)

                // 真经文依据卡：Yi 消息附卦时，确定性拼接展示（不喂模型，G 维度满分）
                if message.role == .yi,
                   let hid = message.attachedHexagramID,
                   let hex = HexagramDataStore.shared.hexagram(byID: hid) {
                    let transformed = conversation.activeCasting?
                        .transformedHexagramID
                        .flatMap { HexagramDataStore.shared.hexagram(byID: $0) }
                    let changing = conversation.activeCasting?.changingLineIndices ?? []
                    canonicalBasisCard(
                        primary: hex,
                        transformed: transformed,
                        changingLineIndices: changing
                    )
                }
            }

            if message.role != .user {
                Spacer(minLength: 40)
            }
        }
    }

    private var bubbleBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(message.role == .user ?
                  theme.palette.accent :
                  theme.palette.ink.opacity(0.06))
    }

    /// 真经文依据卡：展示与本条 Yi 回应关联的卦之权威经文，
    /// 锚定读法时同时展示本卦 + 之卦 + 变爻真爻辞，保持易经逻辑的完整可读。
    /// 来自 Hexagram 模型 + IChingCorpus，确定性拼接，可审计。
    private func canonicalBasisCard(
        primary: Hexagram,
        transformed: Hexagram?,
        changingLineIndices: [Int]
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Authentic I Ching basis")
                .font(.caption2)
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            Text(PromptBuilder.canonicalBasis(
                primary: primary,
                transformed: transformed,
                changingLineIndices: changingLineIndices
            ))
            .font(.caption)
            .foregroundColor(.secondary)
            .italic()
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.palette.ink.opacity(0.04))
        )
    }

    /// 进行中的读法横幅：一眼看清本次对话锚定的起卦与演化方向。
    private var activeReadingBanner: some View {
        guard let cr = conversation.activeCasting,
              let primary = HexagramDataStore.shared.hexagram(byID: cr.primaryHexagramID) else {
            return AnyView(EmptyView())
        }
        let transformed = cr.transformedHexagramID.flatMap { HexagramDataStore.shared.hexagram(byID: $0) }
        let linePos = cr.changingLineIndices.map { $0 + 1 }.sorted()

        return AnyView(
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "link.circle.fill")
                        .foregroundColor(theme.palette.accent)
                    Text("Active Reading")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.palette.ink)
                    Spacer()
                }
                HStack(spacing: 6) {
                    Text("\(primary.symbol) \(primary.nameEN)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(theme.palette.ink)
                    if let t = transformed {
                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(t.symbol) \(t.nameEN)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(theme.palette.ink)
                    }
                }
                if !linePos.isEmpty {
                    Text("Changing lines: \(linePos.map { "Line \($0)" }.joined(separator: ", "))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(theme.palette.accent.opacity(0.08))
            )
        )
    }
}

/// 流式输出气泡
struct StreamingBubbleView: View {
    let text: String
    let theme: AppTheme

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Yi")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 4)

                HStack(alignment: .bottom, spacing: 2) {
                    Text(text)
                        .font(.body)
                        .foregroundColor(.primary)
                    Text("...")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .opacity(0.5)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(theme.palette.ink.opacity(0.06))
                )
            }
            Spacer(minLength: 40)
        }
    }
}
