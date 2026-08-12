import SwiftUI
import StoreKit

/// 付费墙
///
/// 触发时机：用户尝试需要完整体验的功能（无限深度解读 / 专项包 / 年度运势）时弹出。
/// 设计遵循评审 P2 的辩证取舍：先讲「免费价值闭环永远免费」，再卖买断与微交易，
/// 制造「持续得到新东西」的预期，而非一次性收钱就结束。
struct PaywallView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.appTheme) var theme

    private let store = StoreManager.shared

    @State private var isRestoring = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 头部
                    headerView

                    // 价值主张
                    valuePropsView

                    // 商品
                    productsView

                    // 恢复购买
                    restoreButton

                    // 信任脚注
                    trustFooter
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .background(theme.palette.backgroundGradient)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(theme.palette.ink.opacity(0.6))
                    }
                }
            }
            .task {
                await store.loadProducts()
            }
        }
    }

    // MARK: - 头部

    private var headerView: some View {
        VStack(spacing: 10) {
            Text("Yi Oracle")
                .font(.largeTitle)
                .fontWeight(.medium)
                .foregroundColor(theme.palette.ink)

            Text("A companion for a calmer, clearer mind.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - 价值主张

    private var valuePropsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            valueRow(icon: "lock.shield", text: "Everything stays on your device. No accounts, no uploads.")
            valueRow(icon: "brain", text: "Yi remembers you across every reflection.")
            valueRow(icon: "square.grid.3x3", text: "All 64 hexagrams, unlocked over time.")
            valueRow(icon: "gift", text: "Daily reflection & your daily hexagram are always free.")
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.palette.cardBackground)
                .shadow(color: theme.palette.shadow, radius: 8, y: 3)
        )
    }

    private func valueRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(theme.palette.accent)
                .frame(width: 22)
            Text(text)
                .font(.subheadline)
                .foregroundColor(theme.palette.textPrimary)
            Spacer()
        }
    }

    // MARK: - 商品

    @ViewBuilder
    private var productsView: some View {
        if store.products.isEmpty {
            if store.isLoading {
                ProgressView("Loading plans...")
                    .padding()
            } else {
                // 无法加载商品时的兜底（如未配置商店 / 测试环境）
                lifetimeFallbackButton
            }
        } else {
            VStack(spacing: 12) {
                // 买断置顶
                if let lifetime = store.products.first(where: { $0.id == StoreManager.ProductID.lifetime.rawValue }) {
                    productCard(product: lifetime, isPrimary: true)
                }
                // 微交易说明（用户不知买什么时的补救：明确两类一次性附加包）
                microNote
                // 微交易
                ForEach(store.products.filter { $0.id != StoreManager.ProductID.lifetime.rawValue }) { product in
                    productCard(product: product, isPrimary: false)
                }
            }
        }
    }

    /// 微交易用途说明：买断之外的一次性附加包，让用户在付费墙内明确"买什么"
    private var microNote: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("One-time add-ons")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(theme.palette.ink)
            Text("Deep Reading opens a longer reading of any hexagram. Topic Packs focus on love, career, or health. Yearly Report maps your year ahead from the I Ching. None expire, none are subscriptions.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.palette.ink.opacity(0.04))
        )
    }

    private func productCard(product: Product, isPrimary: Bool) -> some View {
        Button {
            Task {
                let success = (try? await store.purchase(product)) ?? false
                if success {
                    dismiss()
                }
            }
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(productTitle(product.id))
                        .font(.headline)
                        .foregroundColor(theme.palette.ink)
                    Text(productSubtitle(product.id))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Text(product.displayPrice)
                    .font(.headline)
                    .foregroundColor(theme.palette.ink)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isPrimary ? theme.palette.accent : theme.palette.cardBackground)
                    .shadow(color: theme.palette.shadow, radius: isPrimary ? 10 : 4, y: 3)
            )
        }
        .buttonStyle(.plain)
        .disabled(store.isPurchasing)
    }

    private var lifetimeFallbackButton: some View {
        Button {
            Task { await store.restorePurchases() }
        } label: {
            HStack {
                Spacer()
                Text("Restore Purchases")
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(theme.palette.accent)
            )
            .foregroundColor(theme.palette.textOnAccent)
        }
        .buttonStyle(.plain)
    }

    private var restoreButton: some View {
        Button {
            isRestoring = true
            Task {
                await store.restorePurchases()
                isRestoring = false
            }
        } label: {
            HStack(spacing: 8) {
                if isRestoring { ProgressView().scaleEffect(0.8) }
                Text("Restore Purchases")
                    .font(.subheadline)
            }
            .foregroundColor(theme.palette.ink.opacity(0.7))
        }
        .buttonStyle(.plain)
        .disabled(isRestoring)
    }

    private var trustFooter: some View {
        Text("One-time purchase, no subscription, no data selling. Your privacy is the product, not the price.")
            .font(.caption2)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.top, 4)
    }

    // MARK: - 文案映射

    private func productTitle(_ id: String) -> String {
        StoreManager.ProductID(rawValue: id)?.title ?? "Yi Oracle"
    }

    private func productSubtitle(_ id: String) -> String {
        StoreManager.ProductID(rawValue: id)?.subtitle ?? ""
    }
}
