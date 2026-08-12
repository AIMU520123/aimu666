import Foundation

// MARK: - MLC-LLM 推理引擎错误

/// MLC-LLM 推理过程中可能发生的错误
///
/// 覆盖从模型加载到推理完成的全链路错误场景，
/// 每种错误提供用户可读的描述，便于 UI 层直接展示。
enum MLCLLMError: LocalizedError, Equatable {
    /// 模型文件未在 App Bundle 中找到
    case modelNotFound(String)

    /// 模型配置文件缺失或格式错误（mlc-chat-config.json）
    case invalidModelConfig(String)

    /// GPU/Metal 不可用，无法执行推理
    case metalUnavailable

    /// 模型加载失败（权重文件损坏、版本不兼容等）
    case loadFailed(String)

    /// 推理超时（生成时间超过预设阈值）
    case inferenceTimeout

    /// 内存不足，无法完成推理
    case outOfMemory(estimatedMB: Int)

    /// 推理过程中发生内部错误
    case inferenceFailed(String)

    /// 模型未加载即调用推理
    case modelNotLoaded

    /// 模型正在加载中，不可重复加载
    case alreadyLoading

    /// 不支持的模型类型
    case unsupportedModel(String)

    var errorDescription: String? {
        switch self {
        case .modelNotFound(let name):
            return "Model \"\(name)\" was not found in the app bundle. Please ensure model files are included in the build."
        case .invalidModelConfig(let detail):
            return "Model configuration is invalid: \(detail). The mlc-chat-config.json file may be corrupted."
        case .metalUnavailable:
            return "Metal framework is not available on this device. GPU acceleration is required for on-device inference."
        case .loadFailed(let detail):
            return "Failed to load the model: \(detail). Please try restarting the app."
        case .inferenceTimeout:
            return "The model took too long to respond. Please try a shorter message."
        case .outOfMemory(let estimatedMB):
            return "Insufficient memory (needed ~\(estimatedMB) MB). Please close other apps and try again."
        case .inferenceFailed(let detail):
            return "An error occurred during inference: \(detail)"
        case .modelNotLoaded:
            return "The model has not been loaded yet. Please wait for initialization to complete."
        case .alreadyLoading:
            return "The model is currently loading. Please wait..."
        case .unsupportedModel(let name):
            return "Model \"\(name)\" is not supported. Supported models: Qwen2.5-3B-Instruct, Llama-3.2-3B-Instruct."
        }
    }
}

// MARK: - 推理参数配置

/// MLC-LLM 推理参数
///
/// 封装 LLM 生成时的采样参数。
/// 注意：MLC-LLM 的实际采样参数（temperature / top_p 等）在模型打包时写入
/// `mlc-chat-config.json`，运行时通过 `engine.reload(modelPath:modelLib:)` 加载，
/// 因此本结构仅作为应用层的可读配置与文档化用途，运行时请求本身只需 `max_tokens`。
struct MLCInferenceConfig {
    /// 采样温度（0.0=确定性, 1.0=高随机性）
    var temperature: Float = 0.7

    /// 核采样概率阈值（top-p）
    var topP: Float = 0.9

    /// 最大生成 token 数
    var maxTokens: Int = 512

    /// 推理超时时间（秒）
    var timeoutSeconds: TimeInterval = 60.0

    /// 重复惩罚因子
    var repetitionPenalty: Float = 1.1
}

// MARK: - 模型元信息

/// 预定义的模型元信息
///
/// 描述 Yi Oracle 支持的本地模型及其文件结构。
/// 打包流程（`mlc_llm package`）会生成 `<name>-MLC` 目录，
/// 内含 `mlc-chat-config.json` 与编译产物 `<modelLib>.mlib`。
///
/// 修正说明：原始实现同时存在 `enum MLCModelMeta` 与 `struct MLCModelMeta` 两个同名声明，
/// 导致 "Invalid redeclaration of 'MLCModelMeta'" 编译错误。此处合并为单一结构体。
struct MLCModelMeta {
    /// 模型标识（对应 mlc-chat-config.json 的 model_id）
    let name: String
    /// 展示名
    let displayName: String
    /// App Bundle 中的模型目录路径（相对路径），形如 "Models/Qwen2.5-3B-Instruct-q4f16_1-MLC"
    let bundleDirectory: String
    /// 模型库前缀（reload 的 modelLib 参数）
    /// 对应 `mlc_llm compile --model-lib <前缀>` 生成的静态库名（不含扩展名）
    let modelLib: String
    /// MLC-LLM 配置文件名
    let configFileName: String
    /// 预估内存占用（MB）
    let estimatedMemoryMB: Int
    /// 模型上下文长度（token 数）
    let contextLength: Int
    /// 量化方案标识
    let quantization: String

    /// Qwen2.5-3B-Instruct Q4 量化版（推荐）
    static let qwen25_3b = MLCModelMeta(
        name: "Qwen2.5-3B-Instruct-q4f16_1",
        displayName: "Qwen 2.5 3B Instruct (Q4)",
        bundleDirectory: "Models/Qwen2.5-3B-Instruct-q4f16_1-MLC",
        modelLib: "qwen2_5_3b",
        configFileName: "mlc-chat-config.json",
        estimatedMemoryMB: 2400,
        contextLength: 4096,
        quantization: "q4f16_1"
    )

    /// Llama-3.2-3B-Instruct Q4 量化版（备选）
    static let llama32_3b = MLCModelMeta(
        name: "Llama-3.2-3B-Instruct-q4f16_1",
        displayName: "Llama 3.2 3B Instruct (Q4)",
        bundleDirectory: "Models/Llama-3.2-3B-Instruct-q4f16_1-MLC",
        modelLib: "llama_3_2_3b",
        configFileName: "mlc-chat-config.json",
        estimatedMemoryMB: 2300,
        contextLength: 4096,
        quantization: "q4f16_1"
    )

    /// 所有支持的模型
    static let all: [MLCModelMeta] = [qwen25_3b, llama32_3b]

    /// 按名称查找模型元信息
    static func find(named name: String) -> MLCModelMeta? {
        all.first { $0.name == name || $0.displayName == name }
    }
}

// MARK: - 内存监控工具

/// 内存使用监控工具
///
/// 通过 `mach_task_basic_info` 获取当前进程的物理内存占用，
/// 通过 `os_proc_available_memory()` 获取 Jetsam 前的可用上限。
enum MemoryMonitor {
    /// 获取当前进程驻留内存（MB）
    static func currentMemoryUsageMB() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<integer_t>.size)

        let result: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            return Int(info.resident_size) / (1024 * 1024)
        }
        return 0
    }

    /// 获取设备可用内存（MB）
    static func availableMemoryMB() -> Int {
        let availableBytes = os_proc_available_memory()
        if availableBytes > 0 {
            return Int(availableBytes) / (1024 * 1024)
        }
        return 0
    }

    /// 估算推理所需内存（模型大小 + KV Cache + 临时缓冲）
    static func estimatedInferenceMemory(modelMeta: MLCModelMeta, promptTokens: Int = 1024) -> Int {
        let kvCacheEstimate = Int(Double(promptTokens) * 0.5)
        return modelMeta.estimatedMemoryMB + kvCacheEstimate + 200
    }
}

// MARK: - 真实推理引擎（链接 MLCSwift 时编译）

#if canImport(MLCSwift)
import MLCSwift

/// MLC-LLM 真实推理引擎 — 生产环境使用
///
/// 基于官方 `MLCSwift` Swift SDK（OpenAI 兼容接口）实现本地 LLM 推理。
/// 参考实现：https://github.com/mlc-ai/mlc-llm/blob/main/ios/MLCEngineExample
///
/// 关键约束（来自官方文档与 SwiftyMLC 示例）：
/// - `MLCEngine` 的创建与调用必须在 **@MainActor** 上进行（内部使用 Metal / 主线程资源）。
/// - 加载模型：`await engine.reload(modelPath:modelLib:)`。
/// - 生成文本：`for await res in await engine.chat.completions.create(messages:)` 流式循环。
/// - 卸载模型：`await engine.unload()`。
/// - `modelLib` 为打包时编译出的模型库前缀（见 `MLCModelMeta.modelLib`）。
@MainActor
final class MLCLLMEngine: LLMEngineProtocol {
    // MARK: - LLMEngineProtocol 属性

    private(set) var isModelLoaded = false
    private(set) var modelName = ""

    // MARK: - 内部状态

    /// MLC 引擎实例（懒加载于首次 loadModel，确保在 @MainActor 上创建）
    private var engine: MLCEngine?

    /// 模型在文件系统中的路径
    private var resolvedModelPath: String?

    /// 当前推理配置
    private var inferenceConfig: MLCInferenceConfig

    /// 当前是否正在推理
    private var isInferring = false

    /// 模型元信息
    private var modelMeta: MLCModelMeta?

    // MARK: - 初始化

    init(inferenceConfig: MLCInferenceConfig = MLCInferenceConfig()) {
        self.inferenceConfig = inferenceConfig
    }

    // MARK: - 模型加载

    func loadModel(named name: String) async throws -> Bool {
        guard !isModelLoaded else {
            if modelName == name { return true }
            await unloadModel()
        }

        guard let meta = MLCModelMeta.find(named: name)
            ?? MLCModelMeta.all.first(where: { $0.bundleDirectory.contains(name) }) else {
            throw MLCLLMError.unsupportedModel(name)
        }
        self.modelMeta = meta

        // 在 App Bundle 或 Documents 目录定位模型目录
        let bundleURL = Bundle.main.url(forResource: meta.bundleDirectory, withExtension: nil)
        let docsURL = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(meta.bundleDirectory)
        guard let resolvedURL = bundleURL
            ?? (FileManager.default.fileExists(atPath: docsURL.path) ? docsURL : nil) else {
            throw MLCLLMError.modelNotFound(name)
        }

        let configURL = resolvedURL.appendingPathComponent(meta.configFileName)
        guard FileManager.default.fileExists(atPath: configURL.path) else {
            throw MLCLLMError.invalidModelConfig("Missing \(meta.configFileName) in \(resolvedURL.lastPathComponent)")
        }
        self.resolvedModelPath = resolvedURL.path

        // 可用内存预检
        let availableMB = MemoryMonitor.availableMemoryMB()
        if availableMB > 0 && availableMB < meta.estimatedMemoryMB {
            throw MLCLLMError.outOfMemory(estimatedMB: meta.estimatedMemoryMB)
        }

        // 首次使用时在 @MainActor 上创建引擎实例
        if engine == nil {
            engine = MLCEngine()
        }

        // 真实 MLC-LLM API：reload 加载模型权重与编译库
        await engine?.unload()
        await engine?.reload(modelPath: resolvedURL.path, modelLib: meta.modelLib)

        self.modelName = meta.name
        self.isModelLoaded = true
        return true
    }

    // MARK: - 非流式推理

    func generate(prompt: String, maxTokens: Int = 512) async throws -> String {
        guard isModelLoaded else { throw MLCLLMError.modelNotLoaded }
        var config = inferenceConfig
        config.maxTokens = maxTokens
        return try await performInference(prompt: prompt, config: config)
    }

    // MARK: - 流式推理

    func generateStream(
        prompt: String,
        maxTokens: Int = 512,
        onToken: @escaping (String) -> Void
    ) async throws -> String {
        guard isModelLoaded else { throw MLCLLMError.modelNotLoaded }
        var config = inferenceConfig
        config.maxTokens = maxTokens
        return try await performStreamInference(prompt: prompt, config: config, onToken: onToken)
    }

    // MARK: - 卸载模型

    func unloadModel() async {
        guard isModelLoaded else { return }
        await engine?.unload()
        isModelLoaded = false
        modelName = ""
        isInferring = false
        resolvedModelPath = nil
        modelMeta = nil
    }

    // MARK: - 内部推理方法

    private func performInference(prompt: String, config: MLCInferenceConfig) async throws -> String {
        guard !isInferring else {
            throw MLCLLMError.inferenceFailed("Another inference is already running")
        }
        isInferring = true
        defer { isInferring = false }

        preInferenceMemoryCheck()
        return try await withTimeout(seconds: config.timeoutSeconds) {
            try await self.rawGenerate(prompt: prompt, config: config)
        }
    }

    private func performStreamInference(
        prompt: String,
        config: MLCInferenceConfig,
        onToken: @escaping (String) -> Void
    ) async throws -> String {
        guard !isInferring else {
            throw MLCLLMError.inferenceFailed("Another inference is already running")
        }
        isInferring = true
        defer { isInferring = false }

        preInferenceMemoryCheck()
        return try await withTimeout(seconds: config.timeoutSeconds) {
            try await self.rawGenerateStream(prompt: prompt, config: config, onToken: onToken)
        }
    }

    private func preInferenceMemoryCheck() {
        guard let meta = modelMeta else { return }
        let estimated = MemoryMonitor.estimatedInferenceMemory(modelMeta: meta)
        let available = MemoryMonitor.availableMemoryMB()
        if available > 0 && available < estimated {
            // 非致命警告：真实 OOM 会由引擎在生成时抛出错误，这里仅记录
            print("[MLCLLMEngine] Low memory warning before inference: \(available)MB available, ~\(estimated)MB estimated")
        }
    }

    /// 底层推理调用（非流式）
    private func rawGenerate(prompt: String, config: MLCInferenceConfig) async throws -> String {
        let messages: [ChatCompletionMessage] = [
            ChatCompletionMessage(role: .user, content: prompt)
        ]
        var fullText = ""
        for await response in await engine!.chat.completions.create(
            messages: messages,
            max_tokens: config.maxTokens
        ) {
            if let text = response.choices.first?.delta.content?.asText() {
                fullText += text
            }
            if let finish = response.choices.first?.finish_reason, finish == "length" {
                break
            }
        }
        return fullText
    }

    /// 底层推理调用（流式）
    private func rawGenerateStream(
        prompt: String,
        config: MLCInferenceConfig,
        onToken: @escaping (String) -> Void
    ) async throws -> String {
        let messages: [ChatCompletionMessage] = [
            ChatCompletionMessage(role: .user, content: prompt)
        ]
        var fullText = ""
        for await response in await engine!.chat.completions.create(
            messages: messages,
            max_tokens: config.maxTokens
        ) {
            if let text = response.choices.first?.delta.content?.asText() {
                fullText += text
                onToken(text)
            }
            if let finish = response.choices.first?.finish_reason, finish == "length" {
                break
            }
        }
        return fullText
    }

    // MARK: - 超时控制

    private func withTimeout<T>(
        seconds: TimeInterval,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        let timeoutNanoseconds = UInt64(seconds * 1_000_000_000)
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(nanoseconds: timeoutNanoseconds)
                throw MLCLLMError.inferenceTimeout
            }
            guard let result = try await group.next() else {
                throw MLCLLMError.inferenceFailed("Task group returned no results")
            }
            group.cancelAll()
            return result
        }
    }

    // MARK: - 辅助方法

    /// 重置推理上下文（保留已加载模型，仅清空 KV Cache）
    func resetContext() async {
        await engine?.reset()
    }

    /// 获取当前引擎状态摘要（用于调试和 UI 展示）
    func statusDescription() -> String {
        var parts: [String] = []
        parts.append("Model: \(modelName.isEmpty ? "none" : modelName)")
        parts.append("Loaded: \(isModelLoaded)")
        parts.append("Inferring: \(isInferring)")
        if let meta = modelMeta {
            parts.append("Memory: ~\(meta.estimatedMemoryMB)MB")
            parts.append("Context: \(meta.contextLength) tokens")
        }
        parts.append("MaxTokens: \(inferenceConfig.maxTokens)")
        return parts.joined(separator: " | ")
    }
}

// MARK: - 占位引擎（未链接 MLCSwift 时使用）

#else

/// 占位实现：当 MLCSwift 未链接（例如仅运行 Mock 的 CI / 开发构建）时编译通过。
/// 真实推理需链接 MLCSwift 并在主线程创建 `MLCEngine`。
final class MLCLLMEngine: LLMEngineProtocol {
    private(set) var isModelLoaded = false
    private(set) var modelName = ""

    func loadModel(named name: String) async throws -> Bool {
        throw MLCLLMError.loadFailed("MLCSwift is not linked. Add the ios/MLCSwift package to enable on-device inference.")
    }

    func generate(prompt: String, maxTokens: Int = 512) async throws -> String {
        throw MLCLLMError.loadFailed("MLCSwift is not linked.")
    }

    func generateStream(
        prompt: String,
        maxTokens: Int = 512,
        onToken: @escaping (String) -> Void
    ) async throws -> String {
        throw MLCLLMError.loadFailed("MLCSwift is not linked.")
    }

    func unloadModel() async {}
}

#endif

// MARK: - LLMEngineFactory 扩展

/// 更新工厂方法以支持真实引擎创建
///
/// 在链接 MLCSwift 后，`create(useMock: false)` 返回真实 `MLCLLMEngine` 实例。
extension LLMEngineFactory {
    /// 创建 MLC-LLM 真实引擎实例
    static func createMLCEngine() -> MLCLLMEngine {
        MLCLLMEngine()
    }

    /// 创建带自定义配置的 MLC-LLM 引擎
    static func createMLCEngine(config: MLCInferenceConfig) -> MLCLLMEngine {
        MLCLLMEngine(inferenceConfig: config)
    }
}
