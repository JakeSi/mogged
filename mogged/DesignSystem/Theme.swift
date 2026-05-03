import SwiftUI

enum Theme {
    enum Color {
        static let background = SwiftUI.Color.black
        static let card = SwiftUI.Color(white: 0.04)
        static let cardElevated = SwiftUI.Color(white: 0.06)
        static let border = SwiftUI.Color(white: 0.12)
        static let borderHighlight = SwiftUI.Color(white: 0.22)
        static let primaryText = SwiftUI.Color(white: 0.96)
        static let secondaryText = SwiftUI.Color(white: 0.55)
        static let tertiaryText = SwiftUI.Color(white: 0.38)
        static let warning = SwiftUI.Color(red: 0.92, green: 0.74, blue: 0.20)
        static let invalid = SwiftUI.Color(red: 0.86, green: 0.36, blue: 0.36)
        static let valid = SwiftUI.Color(white: 0.85)
    }

    enum Gradient {
        static let ring = LinearGradient(
            colors: [
                SwiftUI.Color(white: 0.95),
                SwiftUI.Color(white: 0.55),
                SwiftUI.Color(white: 0.30)
            ],
            startPoint: .top,
            endPoint: .bottom
        )

        static let ringTrack = LinearGradient(
            colors: [
                SwiftUI.Color(white: 0.18),
                SwiftUI.Color(white: 0.10)
            ],
            startPoint: .top,
            endPoint: .bottom
        )

        static let pageBackdrop = RadialGradient(
            colors: [
                SwiftUI.Color(white: 0.045),
                SwiftUI.Color.black
            ],
            center: .top,
            startRadius: 40,
            endRadius: 600
        )
    }

    enum Radius {
        static let card: CGFloat = 24
        static let chip: CGFloat = 12
        static let button: CGFloat = 18
    }
}
