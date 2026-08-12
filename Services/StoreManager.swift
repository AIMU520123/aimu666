import Foundation
import StoreKit

/// 内购与权益管理（StoreKit 2）
///
/// 解决产品总监评审的 P0-1「商业化完全未接线」：
/// - 真实加载 App Store Connect 配置的商品（含本地 Products.storekit 用于开发期测试）
/// - 一次性买断（Lifetime）+ 微交易（深度解读 / 专项包 / 年度运势）双轨收入
/// - 通过 `Transaction.currentEntitlements` 跨设备恢复购买（满足 3.1.1，无需自建账户）
/// - 监听 `Transaction.updates` 自动同步权益状态
///
/// 设计取舍（辩证）：
/// $39.99 买断消除月流失也消除持续回访动机。因此定价采用
/// 「免费价值闭环（每日反思 + 每日一卦永久免费）+ 买断完整体验 + 微交易养持续收入」。
@MainActor
@Observable
final class StoreManager {
    /// 单例：全 App 共享同一权益状态
    static let shared = StoreManager()

    /// 商品 ID 枚举（与 Products.storekit / App Store Connect 一一对应）
    enum ProductID: String, CaseIterable, Identifiable {
        case lifetime    = "com.yioracle.lifetime"
        case deepReading = "com.yioracle.deepreading"
        case topicPack   = "com.yioracle.topicpack"
        case yearlyReport = "com.yioracle.yearlyreport"

        var id: String { rawValue }

        /// 展示用文案（英文，面向海外用户）
        var title: String {
            switch self {
            case .lifetime:     return "Lifetime Access"
            case .deepReading:  return "Deep Reading"
            case .topicPack:    return "Topic Pack"
            case .yearlyReport: return "Yearly Report"
            }
        }

        var subtitle: String {
            switch self {
            case .lifetime:     return "Everything, forever. One payment."
            case .deepReading:  return "A longer, layered reading of any hexagram"
            case .topicPack:    return "Love, career, or health focus packs"
            case .yearlyReport: return "Your year ahead, mapped from the I Ching"
            }
        }

        /// 是否一次性买断（影响权益判定）
        var isEntitlement: Bool {
            switch self {
            case .lifetime: return true
            default:        return false
            }
        }
    }

    // MARK: - 公开状态（UI 绑定）

    /// 已加载的商品
    private(set) var products: [Product] = []

    /// 已购商品 ID 集合（权益真值来源）
    private(set) var purchasedProductIDs: Set<String> = []

    /// 是否正在加载商品
    var isLoading: Bool = false

    /// 最近一次错误信息
    var errorMessage: String?

    /// 购买流程是否进行中
    var isPurchasing: Bool = false

    // MARK: - 权益判定

    /// 是否已解锁完整体验（买断）
    var isPremium: Bool {
        purchasedProductIDs.contains(ProductID.lifetime.rawValue)
    }

    /// 是否已购买任一微交易（用于埋点/个性化）
    var hasMicroPurchase: Bool {
        purchasedProductIDs.contains {
            $0 != ProductID.lifetime.rawValue
        }
    }

    // MARK: - 初始化

    private var updatesTask: Task<Void, Never>?

    private init() {
        updatesTask = observeTransactionUpdates()
    }

    // MARK: - 商品加载

    /// 从 App Store 加载全部商品
    func loadProducts() async {
        guard products.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            products = try await Product.products(for: ProductID.allCases.map { $0.rawValue })
            await refreshEntitlements()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - 购买

    /// 购买指定商品
    /// - Returns: 是否成功完成支付
    @discardableResult
    func purchase(_ product: Product) async throws -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await finalize(transaction)
            return true
        case .userCancelled, .pending:
            return false
        @unknown default:
            return false
        }
    }

    /// 恢复购买（满足 Apple 3.1.1 非消耗型恢复要求）
    func restorePurchases() async {
        do {
            try await AppStore.sync()
        } catch {
            errorMessage = error.localizedDescription
        }
        await refreshEntitlements()
    }

    // MARK: - 交易监听

    /// 监听 Transaction.updates，自动同步权益（跨设备、订阅续期等）
    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task {
            for await update in Transaction.updates {
                guard let transaction = try? await checkVerified(update) else { continue }
                await finalize(transaction)
            }
        }
    }

    // MARK: - 权益刷新

    private func refreshEntitlements() async {
        var ids = Set<String>()
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result),
                  transaction.revocationDate == nil else { continue }
            ids.insert(transaction.productID)
        }
        purchasedProductIDs = ids
        syncToUserDefaults()
    }

    private func finalize(_ transaction: Transaction) async {
        purchasedProductIDs.insert(transaction.productID)
        syncToUserDefaults()
        await transaction.finish()
    }

    private func syncToUserDefaults() {
        let defaults = UserDefaultsManager.shared
        defaults.purchaseVerified = isPremium
        if isPremium, defaults.purchaseDate == nil {
            defaults.purchaseDate = Date()
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe): return safe
        case .unverified(_, let error): throw error
        }
    }
}
