import SwiftUI
import UIKit

/// 分享卡三套皮肤：墨 / 金 / 玉。
///
/// 设计意图（借 Co-Star「品牌美学即内容」机制，但保留离线）：
/// - 出社交平台的卡需要视觉张力，三套中式配色让同一卦象有不同情绪表达。
/// - 全部为静态命名色，不依赖运行时主题，保证分享图观感确定、可截图传播。
enum ReflectionCardSkin: String, CaseIterable, Identifiable {
    case ink  // 墨：宣纸黑墨，克制高级
    case gold // 金：暖金米色，温润贵气
    case jade // 玉：深玉夜色，沉静神秘

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ink:  return "Ink"
        case .gold: return "Gold"
        case .jade: return "Jade"
        }
    }

    /// 选择器色块
    var swatch: Color {
        switch self {
        case .ink:  return Color(hex: 0x1A1A1A)
        case .gold: return Color(hex: 0xB8842D)
        case .jade: return Color(hex: 0x4FB286)
        }
    }

    var background: Color {
        switch self {
        case .ink:  return Color(hex: 0xFFFFFF)
        case .gold: return Color(hex: 0xFBF6EC)
        case .jade: return Color(hex: 0x0F1F1A)
        }
    }
    var cardBackground: Color {
        switch self {
        case .ink:  return Color(hex: 0xFAF8F3)
        case .gold: return Color(hex: 0xFFFDF8)
        case .jade: return Color(hex: 0x16291F)
        }
    }
    var cardBorder: Color {
        switch self {
        case .ink:  return Color(hex: 0xE5E0D8)
        case .gold: return Color(hex: 0xEAD9B0)
        case .jade: return Color(hex: 0x2E4A3A)
        }
    }
    var ink: Color {
        switch self {
        case .ink:  return Color(hex: 0x1A1A1A)
        case .gold: return Color(hex: 0x2B2117)
        case .jade: return Color(hex: 0xE8F3EC)
        }
    }
    var accent: Color {
        switch self {
        case .ink:  return Color(hex: 0x6B5B4F)
        case .gold: return Color(hex: 0xB8842D)
        case .jade: return Color(hex: 0x4FB286)
        }
    }
    var gold: Color {
        switch self {
        case .ink:  return Color(hex: 0xB8932F)
        case .gold: return Color(hex: 0xB8842D)
        case .jade: return Color(hex: 0xC9A24B)
        }
    }
    var textPrimary: Color {
        switch self {
        case .ink:  return Color(hex: 0x3A352F)
        case .gold: return Color(hex: 0x4A3B28)
        case .jade: return Color(hex: 0xC7DBCF)
        }
    }
}

/// 可离线渲染、可分享的「反思卡」。
///
/// 关键约束：出设备的是一张静态图，不含任何对话内容或个人数据，
/// 完全符合 Yi Oracle 的离线隐私定位（借 Co-Star「截图即内容」机制，但不触碰云端）。
struct ReflectionCard: View {
    let hexagram: Hexagram
    let template: ReflectionTemplate
    let skin: ReflectionCardSkin
    let signature: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("YI ORACLE")
                    .font(.caption)
                    .fontWeight(.bold)
                    .tracking(2)
                    .foregroundColor(skin.gold)
                Spacer()
                Text("Daily Reflection")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(hexagram.symbol)
                .font(.system(size: 60))
                .foregroundColor(skin.ink)

            VStack(alignment: .leading, spacing: 4) {
                Text(hexagram.nameEN)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(skin.ink)
                Text(hexagram.coreMeaning)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Divider()
                .background(skin.cardBorder)

            VStack(alignment: .leading, spacing: 6) {
                Text(template.title)
                    .font(.headline)
                    .foregroundColor(skin.ink)
                Text(template.content)
                    .font(.callout)
                    .foregroundColor(skin.textPrimary)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Yi 签名金句（可被截图传播的人格锚点）
            Text("\"\(signature)\"")
                .font(.callout)
                .italic()
                .foregroundColor(skin.accent)
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
                .fill(skin.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(skin.cardBorder, lineWidth: 1)
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

// MARK: - 颜色工具

extension Color {
    /// 由十六进制整型构造 Color（用于分享卡皮肤的确定配色）
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1.0)
    }
}
