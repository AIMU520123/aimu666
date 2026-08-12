import SwiftUI
import UIKit

/// 可离线渲染、可分享的「反思卡」。
///
/// 关键约束：出设备的是一张静态图，不含任何对话内容或个人数据，
/// 完全符合 Yi Oracle 的离线隐私定位（借 Co-Star「截图即内容」机制，但不触碰云端）。
struct ReflectionCard: View {
    let hexagram: Hexagram
    let template: ReflectionTemplate
    let theme: AppTheme
    let signature: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("YI ORACLE")
                    .font(.caption)
                    .fontWeight(.bold)
                    .tracking(2)
                    .foregroundColor(theme.palette.gold)
                Spacer()
                Text("Daily Reflection")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(hexagram.symbol)
                .font(.system(size: 60))
                .foregroundColor(theme.palette.ink)

            VStack(alignment: .leading, spacing: 4) {
                Text(hexagram.nameEN)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.palette.ink)
                Text(hexagram.coreMeaning)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Divider()
                .background(theme.palette.cardBorder)

            VStack(alignment: .leading, spacing: 6) {
                Text(template.title)
                    .font(.headline)
                    .foregroundColor(theme.palette.ink)
                Text(template.content)
                    .font(.callout)
                    .foregroundColor(theme.palette.textPrimary)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Yi 签名金句（可被截图传播的人格锚点）
            Text("\"\(signature)\"")
                .font(.callout)
                .italic()
                .foregroundColor(theme.palette.accent)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()
                Text("— Yi")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .padding(26)
        .frame(width: 340)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(theme.palette.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(theme.palette.cardBorder, lineWidth: 1)
                )
        )
    }
}

/// 把 UIImage 接入 SwiftUI 的 sheet(item:)
/// 注：ShareSheet 已在 HexagramDetailView.swift 定义，本模块复用，不再重复声明。
struct IdentifiableImage: Identifiable {
    let id = UUID()

    let image: UIImage
}
