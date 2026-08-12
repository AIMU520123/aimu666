import SwiftUI

/// 64卦收集系统
///
/// 以网格形式展示全部64卦的收集状态：
/// - 已解锁：完整显示卦象符号和名称
/// - 未解锁：半透明显示，覆盖"Discover through reflection"提示
///
/// 设计意图：
/// - 游戏化元素（收集进度）提升用户粘性
/// - 解锁方式自然：通过每日反思/占卜自然触发
/// - 视觉奖励：完整的64卦网格有强烈的满足感
/// - 不强调"集齐全部"的紧迫感 — 这更像是自然积累
///
/// 布局：
/// - 顶部：收集进度条 + 已解锁统计
/// - 主体：8x8网格（64卦）
/// - 点击已解锁卦象跳转详情页
struct CollectionView: View {
    @Binding var userProfile: UserProfile

    @Environment(\.appTheme) var theme

    @State private var allHexagrams: [Hexagram] = []
    @State private var selectedHexagram: Hexagram?
    @State private var showDetail = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 8)

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 进度统计
                progressSection
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)

                Divider()
                    .background(theme.palette.ink.opacity(0.1))

                // 64卦网格
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 4) {
                        ForEach(allHexagrams) { hex in
                            collectionCell(for: hex)
                        }
                    }
                    .padding(12)
                }
            }
            .background(theme.palette.backgroundGradient)
            .navigationTitle("Collection")
            .navigationDestination(isPresented: $showDetail) {
                if let hex = selectedHexagram {
                    HexagramDetailView(hexagram: hex, userProfile: $userProfile)
                }
            }
            .task {
                loadHexagrams()
            }
        }
    }

    // MARK: - 进度统计

    private var progressSection: some View {
        VStack(spacing: 8) {
            // 进度条
            HStack(spacing: 12) {
                // 进度条
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(theme.palette.ink.opacity(0.1))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(theme.palette.ink)
                            .frame(
                                width: geometry.size.width * CGFloat(userProfile.collectionProgress),
                                height: 6
                            )
                    }
                }
                .frame(height: 6)

                Text("\(userProfile.unlockedHexagramIDs.count)/64")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(theme.palette.ink)
                    .monospacedDigit()
            }

            // 说明文字
            HStack {
                Text("Each hexagram is discovered through reflection — no rush, no grind.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - 网格单元

    private func collectionCell(for hex: Hexagram) -> some View {
        let isUnlocked = userProfile.unlockedHexagramIDs.contains(hex.id)

        return Button {
            if isUnlocked {
                selectedHexagram = hex
                showDetail = true
            }
        } label: {
            VStack(spacing: 2) {
                Text(hex.symbol)
                    .font(.system(size: 28))
                    .foregroundColor(isUnlocked ? theme.palette.ink : theme.palette.ink.opacity(0.2))

                Text("\(hex.id)")
                    .font(.system(size: 9))
                    .foregroundColor(
                        isUnlocked ? .secondary : theme.palette.ink.opacity(0.2)
                    )
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 48)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isUnlocked ?
                          theme.palette.ink.opacity(0.04) :
                          theme.palette.ink.opacity(0.02))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        isUnlocked ?
                        theme.palette.ink.opacity(0.15) :
                        theme.palette.ink.opacity(0.05),
                        lineWidth: 0.5
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(!isUnlocked)
    }

    // MARK: - 数据加载

    private func loadHexagrams() {
        let baseData = HexagramDataStore.shared.allHexagrams

        allHexagrams = baseData.map { hex in
            var mutable = hex
            mutable.isUnlocked = userProfile.unlockedHexagramIDs.contains(hex.id)
            return mutable
        }
    }
}
