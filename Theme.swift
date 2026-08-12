import SwiftUI

/// 界面风格（Skin）枚举
///
/// Yi Oracle 提供三套可切换的视觉皮肤，覆盖不同用户审美取向：
/// 1. fantasyYoung  — 中国玄幻风格（年轻向）：暗夜霓光、紫青流转，修仙/国漫质感
/// 2. classicIChing — 中国易经风（纯粹中国风）：宣纸朱砂、水墨印章，学者/典籍质感
/// 3. femaleFantasy — 女性玄幻风格（适配女性）：月华玫瑰、淡紫柔光，温润/梦境质感
///
/// 设计原则：
/// - 每套皮肤自带完整的色彩语义（背景、墨色、强调色、金、卡片），不依赖 Asset Catalog 硬编码
/// - 通过 `Environment(\.appTheme)` 注入，视图读取 `theme.palette.*` 即可获得主题色
/// - 切换皮肤无需重新编译，运行时由 UserDefaultsManager.selectedTheme 驱动
enum AppTheme: String, CaseIterable, Identifiable, Codable {
    case fantasyYoung  = "fantasy_young"
    case classicIChing = "classic_iching"
    case femaleFantasy = "female_fantasy"

    var id: String { rawValue }

    /// 设置页展示名（英文，面向海外用户）
    var displayName: String {
        switch self {
        case .fantasyYoung:  return "Chinese Fantasy"
        case .classicIChing: return "Classic I Ching"
        case .femaleFantasy: return "Grace (Female)"
        }
    }

    /// 设置页副标题
    var subtitle: String {
        switch self {
        case .fantasyYoung:  return "Mystical · Energetic · Young"
        case .classicIChing: return "Pure · Scholarly · Timeless"
        case .femaleFantasy: return "Soft · Elegant · Lunar"
        }
    }

    /// 是否为暗色皮肤（影响状态栏文字、默认材质）
    var isDark: Bool {
        switch self {
        case .fantasyYoung:  return true
        case .classicIChing, .femaleFantasy: return false
        }
    }

    /// 完整调色板
    var palette: AppPalette {
        switch self {
        case .fantasyYoung:  return .fantasyYoung
        case .classicIChing: return .classicIChing
        case .femaleFantasy: return .femaleFantasy
        }
    }
}

/// 主题调色板
///
/// 集中定义一套皮肤所需的全部语义色。视图只引用语义名，不直接写 hex，
/// 这样换肤时只需改 `AppPalette` 静态属性。
struct AppPalette {
    // 背景渐变三段
    let bgTop: Color
    let bgMid: Color
    let bgBottom: Color

    // 墨色：主线条、卦象爻线、主标题
    let ink: Color

    // 强调色：主按钮、激活态、关键点缀
    let accent: Color
    let accentSoft: Color

    // 金/点缀色
    let gold: Color

    // 卡片
    let cardBackground: Color
    let cardBorder: Color

    // 文字
    let textPrimary: Color
    let textSecondary: Color
    let textOnAccent: Color

    // 阴影与光晕
    let shadow: Color
    let glow: Color

    // MARK: - 中国玄幻风格（年轻向）
    static let fantasyYoung = AppPalette(
        bgTop:        Color(hex: "120A24"),
        bgMid:        Color(hex: "1E1140"),
        bgBottom:     Color(hex: "0B0820"),
        ink:          Color(hex: "7DF9FF"),
        accent:       Color(hex: "B15CFF"),
        accentSoft:   Color(hex: "B15CFF").opacity(0.16),
        gold:         Color(hex: "FBD36B"),
        cardBackground: Color(hex: "281850").opacity(0.55),
        cardBorder:   Color(hex: "B15CFF").opacity(0.35),
        textPrimary:  Color(hex: "EAEEFF"),
        textSecondary: Color(hex: "9AA0C8"),
        textOnAccent: Color(hex: "FFFFFF"),
        shadow:       Color(hex: "B15CFF").opacity(0.35),
        glow:         Color(hex: "B15CFF")
    )

    // MARK: - 中国易经风（纯粹中国风）
    static let classicIChing = AppPalette(
        bgTop:        Color(hex: "F5EEDF"),
        bgMid:        Color(hex: "ECE0CA"),
        bgBottom:     Color(hex: "F5EEDF"),
        ink:          Color(hex: "211E1A"),
        accent:       Color(hex: "9E2B25"),
        accentSoft:   Color(hex: "9E2B25").opacity(0.12),
        gold:         Color(hex: "B08D57"),
        cardBackground: Color(hex: "FBF6EA"),
        cardBorder:   Color(hex: "211E1A").opacity(0.12),
        textPrimary:  Color(hex: "211E1A"),
        textSecondary: Color(hex: "6B6359"),
        textOnAccent: Color(hex: "FFFFFF"),
        shadow:       Color(hex: "211E1A").opacity(0.08),
        glow:         Color(hex: "9E2B25")
    )

    // MARK: - 女性玄幻风格（适配女性）
    static let femaleFantasy = AppPalette(
        bgTop:        Color(hex: "FDF1F7"),
        bgMid:        Color(hex: "FCE4F0"),
        bgBottom:     Color(hex: "F6EEFB"),
        ink:          Color(hex: "4A2C3A"),
        accent:       Color(hex: "E58FB3"),
        accentSoft:   Color(hex: "E58FB3").opacity(0.16),
        gold:         Color(hex: "D4B88F"),
        cardBackground: Color(hex: "FFF9FC"),
        cardBorder:   Color(hex: "E58FB3").opacity(0.30),
        textPrimary:  Color(hex: "4A2C3A"),
        textSecondary: Color(hex: "9C7E8E"),
        textOnAccent: Color(hex: "FFFFFF"),
        shadow:       Color(hex: "E58FB3").opacity(0.22),
        glow:         Color(hex: "E58FB3")
    )
}

// MARK: - 调色板辅助

extension AppPalette {
    /// 背景渐变（竖直方向，三段）
    var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [bgTop, bgMid, bgBottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Environment 注入

private struct AppThemeKey: EnvironmentKey {
    static let defaultValue: AppTheme = .classicIChing
}

extension EnvironmentValues {
    /// 当前界面风格，视图通过 `@Environment(\.appTheme) var theme` 读取
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}

// MARK: - Color(hex:) 扩展

extension Color {
    /// 从十六进制字符串构造颜色，支持 #RGB / #RRGGBB / #RRGGBBAA
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB
            (a, r, g, b) = (255,
                            (int >> 8) * 17,
                            (int >> 4 & 0xF) * 17,
                            (int & 0xF) * 17)
        case 6: // RRGGBB
            (a, r, g, b) = (255,
                            int >> 16,
                            int >> 8 & 0xFF,
                            int & 0xFF)
        case 8: // RRGGBBAA
            (a, r, g, b) = (int >> 24,
                            int >> 16 & 0xFF,
                            int >> 8 & 0xFF,
                            int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
