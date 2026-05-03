import SwiftUI

enum AppType {
    static let hero = Font.system(size: 56, weight: .bold)
    static let heroItalic = Font.system(size: 56, weight: .bold).italic()
    static let display = Font.system(size: 96, weight: .bold)
    static let displayItalic = Font.system(size: 96, weight: .bold).italic()
    static let cardTitle = Font.system(size: 20, weight: .bold)
    static let cardScore = Font.system(size: 28, weight: .bold).monospacedDigit()
    static let body = Font.system(size: 14, weight: .regular)
    static let bodyEmphasis = Font.system(size: 14, weight: .semibold)
    static let caption = Font.system(size: 12, weight: .regular)
    static let captionEmphasis = Font.system(size: 12, weight: .semibold)
}

struct EyebrowLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .regular))
            .tracking(2.0)
            .textCase(.uppercase)
            .foregroundStyle(Theme.Color.tertiaryText)
    }
}
