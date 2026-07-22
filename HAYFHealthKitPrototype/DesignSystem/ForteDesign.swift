import SwiftUI

enum ForteColor {
    static let ink = Color(red: 23 / 255, green: 24 / 255, blue: 22 / 255)
    static let inkSoft = Color(red: 63 / 255, green: 64 / 255, blue: 61 / 255)
    static let inkMuted = Color(red: 116 / 255, green: 117 / 255, blue: 111 / 255)

    static let background = Color(red: 250 / 255, green: 249 / 255, blue: 247 / 255)
    static let surface = Color.white
    static let surfaceSoft = Color(red: 245 / 255, green: 243 / 255, blue: 240 / 255)
    static let surfaceRaised = Color(red: 238 / 255, green: 236 / 255, blue: 232 / 255)
    static let surfaceDisabled = Color(red: 232 / 255, green: 230 / 255, blue: 226 / 255)
    static let borderSubtle = Color(red: 227 / 255, green: 224 / 255, blue: 219 / 255)

    static let indigo = Color(red: 79 / 255, green: 70 / 255, blue: 229 / 255)
    static let indigoDeep = Color(red: 55 / 255, green: 48 / 255, blue: 163 / 255)
    static let indigoSoft = Color(red: 237 / 255, green: 233 / 255, blue: 254 / 255)
    static let indigoMist = Color(red: 244 / 255, green: 242 / 255, blue: 252 / 255)
}

enum ForteTypography {
    static func editorial(size: CGFloat, relativeTo textStyle: Font.TextStyle) -> Font {
        .custom("Iowan Old Style", size: size, relativeTo: textStyle)
            .weight(.semibold)
    }
}

enum ForteReviewIconPalette: CaseIterable {
    case indigo
    case teal
    case coral
    case ochre
    case blue
    case rose

    var foreground: Color {
        switch self {
        case .indigo: return Color(red: 80 / 255, green: 67 / 255, blue: 190 / 255)
        case .teal: return Color(red: 29 / 255, green: 126 / 255, blue: 116 / 255)
        case .coral: return Color(red: 205 / 255, green: 82 / 255, blue: 76 / 255)
        case .ochre: return Color(red: 174 / 255, green: 112 / 255, blue: 27 / 255)
        case .blue: return Color(red: 55 / 255, green: 111 / 255, blue: 174 / 255)
        case .rose: return Color(red: 174 / 255, green: 70 / 255, blue: 107 / 255)
        }
    }

    var background: Color {
        switch self {
        case .indigo: return Color(red: 242 / 255, green: 239 / 255, blue: 255 / 255)
        case .teal: return Color(red: 230 / 255, green: 246 / 255, blue: 242 / 255)
        case .coral: return Color(red: 253 / 255, green: 237 / 255, blue: 234 / 255)
        case .ochre: return Color(red: 251 / 255, green: 243 / 255, blue: 222 / 255)
        case .blue: return Color(red: 233 / 255, green: 242 / 255, blue: 252 / 255)
        case .rose: return Color(red: 250 / 255, green: 235 / 255, blue: 241 / 255)
        }
    }

    static func cycling(_ index: Int) -> ForteReviewIconPalette {
        let palettes = allCases
        return palettes[index % palettes.count]
    }
}

struct ForteReviewIconBadge: View {
    let systemName: String
    let palette: ForteReviewIconPalette
    var size: CGFloat = 38
    var iconSize: CGFloat = 16

    var body: some View {
        Image(systemName: systemName)
            .symbolRenderingMode(.hierarchical)
            .font(.system(size: iconSize, weight: .medium))
            .foregroundStyle(palette.foreground)
            .frame(width: size, height: size)
            .background(
                LinearGradient(
                    colors: [palette.background, Color.white.opacity(0.62)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: size * 0.31, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.31, style: .continuous)
                    .stroke(palette.foreground.opacity(0.09), lineWidth: 1)
            }
            .accessibilityHidden(true)
    }
}
