import SwiftUI

/// A small, curated set of "Linktree-style" gradient themes a user can pick
/// for their card. Stored by `id` so it round-trips cleanly through Codable,
/// CloudKit, and the URL-encoded offline format.
public struct CardTheme: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var displayName: String
    public var gradientHexColors: [String]
    public var accentHex: String
    public var prefersLightContent: Bool

    public init(id: String, displayName: String, gradientHexColors: [String], accentHex: String, prefersLightContent: Bool) {
        self.id = id
        self.displayName = displayName
        self.gradientHexColors = gradientHexColors
        self.accentHex = accentHex
        self.prefersLightContent = prefersLightContent
    }

    public var gradientColors: [Color] { gradientHexColors.map(Color.init(hex:)) }
    public var accentColor: Color { Color(hex: accentHex) }

    public var backgroundGradient: LinearGradient {
        LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Foreground color for text/icons drawn directly on `backgroundGradient`.
    public var onGradientForeground: Color { prefersLightContent ? .white : .black }

    public static let midnight = CardTheme(
        id: "midnight",
        displayName: "Midnight",
        gradientHexColors: ["#0F2027", "#203A43", "#2C5364"],
        accentHex: "#7FD8FF",
        prefersLightContent: true
    )

    public static let sunset = CardTheme(
        id: "sunset",
        displayName: "Sunset",
        gradientHexColors: ["#FF512F", "#F09819"],
        accentHex: "#FFFFFF",
        prefersLightContent: true
    )

    public static let aurora = CardTheme(
        id: "aurora",
        displayName: "Aurora",
        gradientHexColors: ["#43CEA2", "#185A9D"],
        accentHex: "#E8FFFB",
        prefersLightContent: true
    )

    public static let blossom = CardTheme(
        id: "blossom",
        displayName: "Blossom",
        gradientHexColors: ["#FFAFBD", "#FFC3A0"],
        accentHex: "#5A2A35",
        prefersLightContent: false
    )

    public static let mono = CardTheme(
        id: "mono",
        displayName: "Mono",
        gradientHexColors: ["#F5F5F7", "#E2E2E7"],
        accentHex: "#111114",
        prefersLightContent: false
    )

    public static let grape = CardTheme(
        id: "grape",
        displayName: "Grape",
        gradientHexColors: ["#41295a", "#2F0743"],
        accentHex: "#D6BBFB",
        prefersLightContent: true
    )

    public static let all: [CardTheme] = [.midnight, .sunset, .aurora, .blossom, .mono, .grape]

    public static func theme(id: String) -> CardTheme {
        all.first(where: { $0.id == id }) ?? .midnight
    }
}

public extension Color {
    /// Convenience hex initializer (`"#RRGGBB"` or `"RRGGBB"`).
    init(hex: String) {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexString = hexString.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&rgb)
        let r = Double((rgb & 0xFF0000) >> 16) / 255
        let g = Double((rgb & 0x00FF00) >> 8) / 255
        let b = Double(rgb & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
