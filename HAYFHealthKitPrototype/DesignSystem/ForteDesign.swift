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
