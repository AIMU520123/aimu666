import Foundation
import SwiftUI
import Combine

// MARK: - 模型状态枚举

/// 模型运行时状态
///
/// 描述模型在生命周期中可能处于的所有状态，
/// 用于 UI 层展示加载进度和管理器内部决策。
enum ModelState: Equatable {
    /// 尚未初始化
    case idle

    /// 正在加载模型
    case loading(progress: Double) // 0.0 - 1.0

    /// 模型已加载，待命中
    case ready

    /// 正在推理
    case inferring

    /// 正在卸载
    case unloading

    /// 模型加载失败
    /// - Parameters: error: 错误描述
    case failed(String)

    /// 模型正在下载（可选功能：模型不在 Bundle 内时）
    case downloading(progress: Double) // 0.0 - 1.0

    /// 模型已卸载（低内存或后台时自动卸载）
    case unloaded(reason: UnloadReason)
}

/// 模型卸载原因
enum UnloadReason: Equatable {
    /// 用户手动卸载
    case manual

    /// 系统低内存警告
    case lowMemory

    /// App 进入后台
    case background

    /// 切换到其他模型
    case switching
}

// MARK: - 模型管理器配置

/// ModelManager 配置选项
///
/// 控制模型管理器的核心行为策略，
/// 可根据不同设备性能或用户偏好调整。
struct ModelManagerConfig {
    /// 是否在 App 启动时自动预加载模型
    /// - iPhone 15 Pro 及以上：推荐 true（加载约 3-5 秒）
    /// - iPhone 12-14：推荐 true（加载约 6-10 秒）
    /// - iPhone 11 及以下：推荐 false（按需加载）
    var preloadOnLaunch: Bool = true

    /// 进入后台时是否自动卸载模型
    /// - true: 节省内存，但回到前台需重新加载（约 3-5 秒）
    /// - false: 保持模型加载，回到前台立即可用（消耗约 2GB 内存）
    var unloadOnBackground: Bool = false

    /// 低内存警告时是否自动卸载模型
    var unloadOnLowMemory: Bool = true

    /// 重新加载模型的重试次数
    var maxRetryCount: Int = 3

    /// 重试间隔（秒）
    var retryDelay: TimeInterval = 1.0

    /// 默认模型名称
    var defaultModelName: String = MLCModelMeta.qwen25_3b.name

    /// 模型是否打包在 App Bundle 中
    /// - true: 模型随 App 分发（App 体积约 2GB+）
    /// - false: 首次使用时从服务器下载（App 体积小，但需要网络）
    var modelBundledInApp: Bool = true

    /// 下载模型的服务器 URL（当 modelBundledInApp = false 时使用）
    var modelDownloadURL: String = ""

    /// 空闲多久后自动卸载模型（秒），0 表示不自动卸载
    var idleTimeoutSeconds: TimeInterval = 0
}

// MARK: - ModelManager

/// 模型管理器 — 管理本地 LLM 的完整生命周期
///
/// 职责：
/// 1. **模型加载/卸载**：管理 MLC-LLM 模型的初始化和释放
/// 2. **内存监控**：实时监控内存使用，低内存时自动卸载
/// 3. **生命周期响应**：处理 App 前后台切换、低内存警告等系统事件
/// 4. **首次启动策略**：预加载模型，优化首次对话体验
/// 5. **模型下载**：当模型不在 Bundle 中时，管理下载和缓存
/// 6. **状态广播**：通过 @Observable 向 UI 层同步模型状态
///
/// 架构设计：
/// ```
/// ┌─────────────────────────────────────────────┐
///                    ModelManager
///                    (@Observable)
/// ┌─────────────┬──────────────┬───────────────┐
/// │  状态管理    │  内存监控     │  生命周期响应  │
/// │  (FSM)      │  (Jetsam)    │  (ScenePhase) │
/// ├─────────────┴──────────────┴───────────────┤
/// │           LLMEngineProtocol                 │
///     ┌─────────────┐    ┌─────────────────┐
///     │ MLCLLMEngine │    │  MockLLMEngine   │
///     │ (生产环境)    │    │  (开发环境)       │
///     └─────────────┘    └─────────────────┘
/// └─────────────────────────────────────────────┘
/// ```
///
/// 使用方式：
/// ```swift
/// @State private var modelManager = ModelManager()
///
/// .onAppear {
///     await modelManager.startup()
/// }
/// .onChange(of: scenePhase) { _, phase in
///     modelManager.handleScenePhase(phase)
/// }
/// ```
@Observable
final class ModelManager {
    /// 单例：全 App 共享同一引擎实例，避免每个 View 重复占内存
    static let shared = ModelManager.create(useMockEngine: true)

    // MARK: - 公开状态（UI 绑定）

    /// 当前模型状态
    var state: ModelState = .idle

    /// 当前加载的模型名称
    var currentModelName: String = ""

    /// 模型是否就绪（可用于推理）
    var isReady: Bool {
        if case .ready = state { return true }
        return false
    }

    /// 当前内存占用（MB），定时更新
    var currentMemoryUsageMB: Int = 0

    /// 加载进度（0.0 - 1.0）
    var loadProgress: Double = 0.0

    /// 最近一次错误信息（nil 表示无错误）
    var lastError: String?

    // MARK: - 内部状态

    /// LLM 引擎实例
    private var engine: LLMEngineProtocol?

    /// 配置
    private let config: ModelManagerConfig

    /// 空闲计时器
    private var idleTimer: Task<Void, Never>?

    /// 内存监控定时器
    private var memoryMonitorTask: Task<Void, Never>?

    /// 重试计数器
    private var retryCount = 0

    /// 是否使用 Mock 引擎（开发环境）
    private let useMockEngine: Bool

    /// 上一次推理时间
    private var lastInferenceTime: Date?

    // MARK: - 初始化

    /// 创建模型管理器
    /// - Parameters:
    ///   - config: 管理器配置
    ///   - useMockEngine: 是否使用 Mock 引擎（开发阶段为 true）
    init(config: ModelManagerConfig = ModelManagerConfig(), useMockEngine: Bool = true) {
        self.config = config
        self.useMockEngine = useMockEngine
    }

    // MARK: - 启动与初始化

    /// 启动模型管理器
    ///
    /// 在 App 启动时调用，执行以下操作：
    /// 1. 创建 LLM 引擎实例
    /// 2. 根据配置决定是否预加载模型
    /// 3. 启动内存监控
    /// 4. 注册系统通知监听
    func startup() async {
        // 创建引擎（MLCLLMEngine 需在主线程创建）
        await createEngine()

        // 启动内存监控
        startMemoryMonitor()

        // 注册系统通知
        registerNotifications()

        // 预加载模型
        if config.preloadOnLaunch {
            await loadModel(config.defaultModelName)
        } else {
            state = .idle
        }
    }

    /// 停止模型管理器，释放所有资源
    func shutdown() async {
        idleTimer?.cancel()
        memoryMonitorTask?.cancel()
        await engine?.unloadModel()
        engine = nil
        state = .idle
        currentModelName = ""
    }

    // MARK: - 模型加载管理

    /// 加载模型
    ///
    /// 根据当前状态执行不同的加载策略：
    /// - 从 idle 状态：首次加载
    /// - 从 unloaded 状态：恢复加载
    /// - 从 ready 状态：如果模型名相同则跳过，不同则先卸载再加载
    /// - 从 failed 状态：重试加载
    ///
    /// - Parameter modelName: 要加载的模型名称
    func loadModel(_ modelName: String) async {
        // 已加载相同模型，无需重复
        if case .ready = state, currentModelName == modelName {
            return
        }

        // 正在加载中，不重复操作
        if case .loading = state { return }
        if case .downloading = state { return }

        state = .loading(progress: 0.0)
        loadProgress = 0.0
        lastError = nil

        // 如果当前已加载不同模型，先卸载
        if case .ready = state, currentModelName != modelName {
            await unloadModelInternal(reason: .switching)
        }

        // 检查模型是否需要下载
        if !config.modelBundledInApp {
            let downloaded = await ensureModelDownloaded(modelName)
            if !downloaded {
                state = .failed("Model download failed")
                return
            }
        }

        // 确保引擎已创建
        if engine == nil {
            await createEngine()
        }

        // 执行加载
        do {
            // 模拟加载进度（实际 MLC-LLM 不提供加载进度回调）
            // 通过分阶段更新进度提供用户体验
            await updateLoadProgress(0.2) // 开始初始化

            let success = try await engine?.loadModel(named: modelName) ?? false

            await updateLoadProgress(0.8) // 模型加载完成

            if success {
                currentModelName = modelName
                state = .ready
                loadProgress = 1.0
                retryCount = 0
                lastInferenceTime = Date()
                startIdleTimerIfNeeded()

                print("[ModelManager] Model loaded: \(modelName)")
            } else {
                throw MLCLLMError.loadFailed("Engine returned false")
            }
        } catch let error as MLCLLMError {
            await handleLoadError(error, modelName: modelName)
        } catch {
            await handleLoadError(
                MLCLLMError.loadFailed(error.localizedDescription),
                modelName: modelName
            )
        }
    }

    /// 卸载模型
    ///
    /// - Parameter reason: 卸载原因
    func unloadModel(reason: UnloadReason = .manual) async {
        await unloadModelInternal(reason: reason)
    }

    /// 内部卸载实现
    private func unloadModelInternal(reason: UnloadReason) async {
        let canUnload: Bool = {
            if isReady { return true }
            if case .failed = state { return true }
            return false
        }()
        guard canUnload else { return }

        state = .unloading
        idleTimer?.cancel()

        await engine?.unloadModel()

        state = .unloaded(reason: reason)
        currentModelName = ""
        loadProgress = 0.0

        // 卸载后检查内存
        currentMemoryUsageMB = MemoryMonitor.currentMemoryUsageMB()

        print("[ModelManager] Model unloaded. Reason: \(reason). Memory: \(currentMemoryUsageMB)MB")
    }

    // MARK: - 推理接口

    /// 生成文本（非流式）
    ///
    /// 封装引擎推理调用，自动处理状态切换和错误恢复。
    /// - Parameters:
    ///   - prompt: 提示词
    ///   - maxTokens: 最大 token 数
    /// - Returns: 生成的文本
    func generate(prompt: String, maxTokens: Int = 512) async throws -> String {
        try await ensureReady()

        state = .inferring
        lastInferenceTime = Date()
        idleTimer?.cancel()

        defer {
            if case .inferring = state {
                state = .ready
            }
            startIdleTimerIfNeeded()
        }

        do {
            return try await engine?.generate(prompt: prompt, maxTokens: maxTokens) ?? ""
        } catch let error as MLCLLMError {
            // 推理失败时检查是否需要卸载模型
            if case .outOfMemory = error {
                await unloadModelInternal(reason: .lowMemory)
            }
            throw error
        }
    }

    /// 生成文本（流式）
    ///
    /// - Parameters:
    ///   - prompt: 提示词
    ///   - maxTokens: 最大 token 数
    ///   - onToken: 逐 token 回调
    /// - Returns: 完整生成文本
    func generateStream(
        prompt: String,
        maxTokens: Int = 512,
        onToken: @escaping (String) -> Void
    ) async throws -> String {
        try await ensureReady()

        state = .inferring
        lastInferenceTime = Date()
        idleTimer?.cancel()

        defer {
            if case .inferring = state {
                state = .ready
            }
            startIdleTimerIfNeeded()
        }

        do {
            return try await engine?.generateStream(
                prompt: prompt,
                maxTokens: maxTokens,
                onToken: onToken
            ) ?? ""
        } catch let error as MLCLLMError {
            if case .outOfMemory = error {
                await unloadModelInternal(reason: .lowMemory)
            }
            throw error
        }
    }

    // MARK: - 生命周期响应

    /// 处理 App 场景阶段变化
    ///
    /// 在 SwiftUI 的 `.onChange(of: scenePhase)` 中调用。
    /// - Parameter phase: 当前场景阶段
    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            Task {
                await handleAppBecameActive()
            }
        case .background:
            handleAppEnteredBackground()
        case .inactive:
            break
        @unknown default:
            break
        }
    }

    /// App 回到前台
    private func handleAppBecameActive() async {
        // 如果模型之前因进入后台而卸载，重新加载
        if case .unloaded(let reason) = state, reason == .background {
            print("[ModelManager] App became active, reloading model...")
            await loadModel(config.defaultModelName)
        }

        // 恢复内存监控
        if memoryMonitorTask == nil {
            startMemoryMonitor()
        }
    }

    /// App 进入后台
    private func handleAppEnteredBackground() {
        if config.unloadOnBackground {
            Task {
                await unloadModelInternal(reason: .background)
            }
        }

        // 停止内存监控（后台不需要）
        memoryMonitorTask?.cancel()
        memoryMonitorTask = nil
    }

    // MARK: - 低内存处理

    /// 处理系统低内存警告
    ///
    /// 在 `UIApplication.didReceiveMemoryWarningNotification` 时调用。
    /// 根据配置决定是否卸载模型以释放内存。
    func handleLowMemoryWarning() {
        guard config.unloadOnLowMemory else { return }

        // 仅在非推理状态下卸载
        guard !isInferringState else {
            print("[ModelManager] Low memory warning received during inference, will unload after completion")
            return
        }

        Task {
            print("[ModelManager] Low memory warning, unloading model to free memory...")
            await unloadModelInternal(reason: .lowMemory)
        }
    }

    /// 当前是否正在推理
    private var isInferringState: Bool {
        if case .inferring = state { return true }
        return false
    }

    // MARK: - 模型下载管理

    /// 确保模型已下载到本地
    ///
    /// 当 `modelBundledInApp = false` 时，首次使用需要下载模型。
    /// - Parameter modelName: 模型名称
    /// - Returns: 是否下载成功或已存在
    private func ensureModelDownloaded(_ modelName: String) async -> Bool {
        let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let modelDir = docsURL.appendingPathComponent("Models/\(modelName)")

        // 检查模型是否已存在
        if FileManager.default.fileExists(atPath: modelDir.path) {
            // 验证模型文件完整性（检查配置文件是否存在）
            let configFile = modelDir.appendingPathComponent("mlc-chat-config.json")
            return FileManager.default.fileExists(atPath: configFile.path)
        }

        // 开始下载
        state = .downloading(progress: 0.0)

        // -------------------------------------------------------------------
        // 模型下载逻辑
        //
        // 实际实现需要：
        // 1. 从 config.modelDownloadURL 下载模型压缩包
        // 2. 解压到 Documents/Models/ 目录
        // 3. 验证文件完整性（checksum）
        //
        // 示例代码：
        //   guard let url = URL(string: config.modelDownloadURL + "/\(modelName).zip") else {
        //       return false
        //   }
        //   let downloadTask = URLSession.shared.downloadTask(with: url) { tempURL, _, _ in
        //       guard let tempURL = tempURL else { return }
        //       try? FileManager.default.unzipItem(at: tempURL, to: modelDir)
        //   }
        //   // 监听下载进度...
        //   // 等待下载完成...
        // -------------------------------------------------------------------

        // 占位：模拟下载失败
        lastError = "Model download is not configured. Set modelBundledInApp = true or configure modelDownloadURL."
        return false
    }

    // MARK: - 内存监控

    /// 启动内存监控定时任务
    ///
    /// 每 5 秒采样一次内存使用量，用于 UI 展示和预警。
    private func startMemoryMonitor() {
        memoryMonitorTask?.cancel()
        memoryMonitorTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self else { break }
                self.currentMemoryUsageMB = MemoryMonitor.currentMemoryUsageMB()

                // 主动检测内存压力
                let available = MemoryMonitor.availableMemoryMB()
                if available > 0 && available < 200 && self.isReady {
                    // 可用内存低于 200MB，主动卸载
                    print("[ModelManager] Available memory low (\(available)MB), proactively unloading")
                    await self.unloadModelInternal(reason: .lowMemory)
                }

                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5s
            }
        }
    }

    // MARK: - 空闲超时

    /// 启动空闲计时器（如果配置了 idleTimeoutSeconds）
    private func startIdleTimerIfNeeded() {
        guard config.idleTimeoutSeconds > 0 else { return }

        idleTimer?.cancel()
        idleTimer = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(self?.config.idleTimeoutSeconds ?? 0) * 1_000_000_000)
            guard !Task.isCancelled, let self = self else { return }

            // 超过空闲时间，卸载模型
            if self.isReady {
                print("[ModelManager] Idle timeout reached, unloading model")
                await self.unloadModelInternal(reason: .manual)
            }
        }
    }

    // MARK: - 错误恢复

    /// 处理模型加载错误
    ///
    /// 根据错误类型决定重试策略：
    /// - 内存不足：等待 2 秒后重试
    /// - 加载失败：重试最多 maxRetryCount 次
    /// - 其他错误：直接标记失败
    private func handleLoadError(_ error: MLCLLMError, modelName: String) async {
        switch error {
        case .outOfMemory(let neededMB):
            lastError = error.errorDescription
            state = .failed("Insufficient memory (\(neededMB)MB needed)")

            // 内存不足时等待后重试
            if retryCount < config.maxRetryCount {
                retryCount += 1
                print("[ModelManager] Retrying after OOM (attempt \(retryCount)/\(config.maxRetryCount))")
                try? await Task.sleep(nanoseconds: UInt64(config.retryDelay * 2) * 1_000_000_000)
                await loadModel(modelName)
            }

        case .loadFailed(let detail):
            lastError = error.errorDescription
            state = .failed(detail)

            // 加载失败时重试
            if retryCount < config.maxRetryCount {
                retryCount += 1
                print("[ModelManager] Retrying after load failure (attempt \(retryCount)/\(config.maxRetryCount))")
                try? await Task.sleep(nanoseconds: UInt64(config.retryDelay) * 1_000_000_000)
                await loadModel(modelName)
            }

        case .metalUnavailable:
            lastError = error.errorDescription
            state = .failed("Metal GPU not available")

        default:
            lastError = error.errorDescription
            state = .failed(error.localizedDescription)
        }
    }

    // MARK: - 辅助方法

    /// 创建 LLM 引擎实例
    ///
    /// `MLCLLMEngine` 内部持有 `MLCEngine`，而 `MLCEngine` 必须在 @MainActor 上创建，
    /// 因此此处通过 `await LLMEngineFactory.create` 在主线程安全地实例化引擎。
    private func createEngine() async {
        guard engine == nil else { return }
        engine = await LLMEngineFactory.create(useMock: useMockEngine)
    }

    /// 确保模型已就绪，否则抛出错误
    private func ensureReady() async throws {
        if case .unloaded(let reason) = state {
            // 模型被卸载（如低内存），尝试重新加载
            print("[ModelManager] Model was unloaded (\(reason)), reloading...")
            await loadModel(config.defaultModelName)
        }

        guard isReady else {
            throw MLCLLMError.modelNotLoaded
        }
    }

    /// 更新加载进度
    private func updateLoadProgress(_ progress: Double) async {
        loadProgress = progress
        state = .loading(progress: progress)
    }

    // MARK: - 通知注册

    /// 注册系统通知监听
    private func registerNotifications() {
        // 低内存警告
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(systemLowMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )

        // App 即将终止
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
    }

    @objc private func systemLowMemoryWarning() {
        handleLowMemoryWarning()
    }

    @objc private func appWillTerminate() {
        Task {
            await shutdown()
        }
    }

    // MARK: - 状态查询

    /// 获取模型状态摘要（用于 UI 调试面板）
    var statusSummary: String {
        let engineType = useMockEngine ? "Mock" : "MLC-LLM"
        return """
        Engine: \(engineType)
        Model: \(currentModelName.isEmpty ? "none" : currentModelName)
        State: \(state)
        Memory: \(currentMemoryUsageMB)MB
        Progress: \(String(format: "%.0f%%", loadProgress * 100))
        Error: \(lastError ?? "none")
        """
    }
}

// MARK: - ScenePhase 扩展

/// ModelManager 场景响应扩展
extension ModelManager {
    /// 在 SwiftUI 视图中绑定场景响应
    ///
    /// 使用方式：
    /// ```swift
    /// .onChange(of: scenePhase) { _, phase in
    ///     modelManager.handleScenePhase(phase)
    /// }
    /// ```
    func bindToScenePhase(_ phase: ScenePhase) {
        handleScenePhase(phase)
    }
}

// MARK: - 设备性能检测

/// 设备性能等级
///
/// 根据设备芯片性能分档，用于决定模型加载策略。
enum DevicePerformanceTier {
    /// 高性能（A16+/M1+）：可流畅运行 3B Q4 模型
    case high
    /// 中等性能（A14-A15）：可运行 3B Q4 模型，推理较慢
    case medium
    /// 低性能（A13 及以下）：建议使用更小模型或按需加载
    case low

    /// 检测当前设备性能等级
    ///
    /// 基于 `ProcessInfo` 的物理内存和 CPU 核心数估算。
    /// 实际生产中可结合 Metal benchmark 进一步精确判断。
    static var current: DevicePerformanceTier {
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        let memoryGB = Double(physicalMemory) / (1024 * 1024 * 1024)

        let processorCount = ProcessInfo.processInfo.processorCount

        // 6GB+ 内存 & 6+ 核心 → 高性能
        if memoryGB >= 5.5 && processorCount >= 6 {
            return .high
        }
        // 4GB+ 内存 & 5+ 核心 → 中等性能
        if memoryGB >= 3.5 && processorCount >= 5 {
            return .medium
        }
        return .low
    }

    /// 推荐的模型加载策略
    var recommendedConfig: ModelManagerConfig {
        switch self {
        case .high:
            // 高性能设备：启动时预加载，后台保持
            return ModelManagerConfig(
                preloadOnLaunch: true,
                unloadOnBackground: false,
                unloadOnLowMemory: true,
                idleTimeoutSeconds: 300 // 5 分钟空闲后卸载
            )
        case .medium:
            // 中等性能：启动时预加载，进入后台时卸载
            return ModelManagerConfig(
                preloadOnLaunch: true,
                unloadOnBackground: true,
                unloadOnLowMemory: true,
                idleTimeoutSeconds: 180 // 3 分钟空闲后卸载
            )
        case .low:
            // 低性能：按需加载，进入后台时卸载
            return ModelManagerConfig(
                preloadOnLaunch: false,
                unloadOnBackground: true,
                unloadOnLowMemory: true,
                idleTimeoutSeconds: 60 // 1 分钟空闲后卸载
            )
        }
    }
}

// MARK: - ModelManager 工厂

/// ModelManager 工厂
extension ModelManager {
    /// 根据设备性能创建配置好的 ModelManager
    ///
    /// 自动检测设备性能等级并应用推荐配置。
    /// - Parameter useMockEngine: 是否使用 Mock 引擎
    /// - Returns: 配置好的 ModelManager 实例
    static func create(useMockEngine: Bool = true) -> ModelManager {
        let tier = DevicePerformanceTier.current
        let config = tier.recommendedConfig
        print("[ModelManager] Device tier: \(tier), config: preload=\(config.preloadOnLaunch), unloadOnBg=\(config.unloadOnBackground)")
        return ModelManager(config: config, useMockEngine: useMockEngine)
    }
}
