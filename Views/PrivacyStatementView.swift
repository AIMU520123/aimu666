import SwiftUI

/// 本地隐私声明页
///
/// 以温暖、真诚的语言向用户说明：
/// - All data stays on this device
/// - No data is sent to any server
/// - You can delete all memory at any time
///
/// 设计意图：
/// - 这是面向海外市场的核心信任建立页面
/// - 不使用法律术语堆砌 — 用普通人能懂的语言
/// - 温暖、真诚、透明的语气
/// - 与PrivacyService的数据绑定，确保内容一致
struct PrivacyStatementView: View {
    @Environment(\.dismiss) var dismiss

    @State private var statement: PrivacyStatement?

    private let privacyService = PrivacyService.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // 标题区域
                    headerSection
                        .padding(.top, 8)

                    // 隐私声明段落
                    VStack(spacing: 28) {
                        if let statement = statement {
                            ForEach(statement.sections) { section in
                                privacySectionView(section)
                            }
                        }
                    }
                    .padding(.top, 24)

                    // 底部说明
                    footerSection
                        .padding(.top, 32)
                        .padding(.bottom, 40)
                }
                .padding(.horizontal, 24)
            }
            .background(Color("YiBackground"))
            .navigationTitle("Your Privacy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                statement = privacyService.privacyStatement()
            }
        }
    }

    // MARK: - 标题区域

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 48))
                .foregroundColor(Color("YiInk"))
                .padding(.bottom, 4)

            Text("Your Privacy is the Foundation")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(Color("YiInk"))
                .multilineTextAlignment(.center)

            Text(
                "Yi Oracle was built from the ground up with one unwavering principle: " +
                "what happens between you and Yi stays between you and your device."
            )
            .font(.subheadline)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .lineSpacing(4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    // MARK: - 隐私段落

    private func privacySectionView(_ section: PrivacySection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: section.icon)
                    .font(.title3)
                    .foregroundColor(Color("YiInk"))

                Text(section.title)
                    .font(.headline)
                    .foregroundColor(Color("YiInk"))
            }

            Text(section.content)
                .font(.body)
                .foregroundColor(.primary)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color("YiInk").opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - 底部

    private var footerSection: some View {
        VStack(spacing: 12) {
            Divider()
                .background(Color("YiInk").opacity(0.15))

            Text("Last updated: \(statement?.lastUpdated.formatted(date: .abbreviated, time: .omitted) ?? "—")")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("Questions? Reach out to us. But honestly, there's not much more to say beyond: **everything stays on your phone, always.**")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.top, 4)
        }
    }
}
