import SwiftUI

// MARK: - Studio BI Design System
// "Intelligent Calm" — Stripe's data clarity + Apple's depth hierarchy

enum DS {

    // MARK: - Spacing (8pt grid)
    enum Spacing {
        static let xs:  CGFloat = 4
        static let sm:  CGFloat = 8
        static let md:  CGFloat = 16
        static let lg:  CGFloat = 24
        static let xl:  CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // MARK: - Corner Radius
    enum Radius {
        static let small:  CGFloat = 8   // badges, pills
        static let medium: CGFloat = 12  // buttons, charts
        static let card:   CGFloat = 16  // cards
        static let sheet:  CGFloat = 20  // bottom sheets
    }

    // MARK: - Colors
    enum Colors {
        static let accent     = Color(hex: "5B6EF0")  // blue-violet
        static let accentSoft = Color(hex: "5B6EF0").opacity(0.1)
        static let success    = Color.green
        static let warning    = Color.orange
        static let error      = Color.red
        static let surface    = Color(.secondarySystemBackground)
        static let muted      = Color(.tertiarySystemBackground)
    }

    // MARK: - Typography helpers
    enum Font {
        static let display    = SwiftUI.Font.system(size: 28, weight: .bold, design: .rounded)
        static let headline   = SwiftUI.Font.system(size: 20, weight: .semibold)
        static let title      = SwiftUI.Font.system(size: 17, weight: .semibold)
        static let body       = SwiftUI.Font.system(size: 15, weight: .regular)
        static let caption    = SwiftUI.Font.system(size: 13, weight: .regular)
        static let captionBold = SwiftUI.Font.system(size: 13, weight: .semibold)
        static let micro      = SwiftUI.Font.system(size: 11, weight: .regular)
        static let mono       = SwiftUI.Font.system(size: 13, design: .monospaced)
        static let monoLarge  = SwiftUI.Font.system(size: 22, weight: .bold, design: .monospaced)
    }

    // MARK: - Component Sizes
    enum Size {
        static let buttonHeight:  CGFloat = 52
        static let pillHeight:    CGFloat = 36
        static let fabSize:       CGFloat = 56
        static let rowHeight:     CGFloat = 52
        static let kpiHeight:     CGFloat = 80
        static let chartHeight:   CGFloat = 240
        static let iconSmall:     CGFloat = 16
        static let iconMedium:    CGFloat = 20
        static let iconLarge:     CGFloat = 28
    }

    // MARK: - Human-readable column type labels
    static func humanColumnType(_ raw: String) -> String {
        switch raw {
        case "METRIC":     return "Sayı"
        case "DIMENSION":  return "Kategori"
        case "DATE":       return "Tarih"
        case "IDENTIFIER": return "Kimlik"
        case "FREE_TEXT":  return "Metin"
        default:           return raw
        }
    }

    static func columnTypeIcon(_ raw: String) -> String {
        switch raw {
        case "DATE":       return "calendar"
        case "METRIC":     return "number"
        case "DIMENSION":  return "tag"
        case "IDENTIFIER": return "key"
        default:           return "text.alignleft"
        }
    }

    static func columnTypeColor(_ raw: String) -> Color {
        switch raw {
        case "DATE":       return .blue
        case "METRIC":     return .green
        case "DIMENSION":  return .orange
        case "IDENTIFIER": return .gray
        default:           return .purple
        }
    }
}

// MARK: - Color hex helper

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Card modifier

struct DSCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(DS.Spacing.md)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.card))
    }
}

extension View {
    func dsCard() -> some View {
        modifier(DSCard())
    }

    func dsCardPadded() -> some View {
        modifier(DSCard()).padding(.horizontal, DS.Spacing.md)
    }
}
