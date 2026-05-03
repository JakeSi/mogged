import SwiftUI

struct CardStyle: ViewModifier {
    var highlighted: Bool = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(Theme.Color.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .stroke(
                        highlighted ? Theme.Color.borderHighlight : Theme.Color.border,
                        lineWidth: highlighted ? 1.0 : 0.5
                    )
            )
    }
}

struct ChipStyle: ViewModifier {
    var tint: Color = Theme.Color.valid

    func body(content: Content) -> some View {
        content
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(Color.black.opacity(0.55))
            )
            .overlay(
                Capsule().stroke(tint.opacity(0.35), lineWidth: 0.5)
            )
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(Color.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                    .fill(Theme.Color.primaryText)
            )
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.smooth(duration: 0.15), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(Theme.Color.primaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                    .fill(Theme.Color.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                    .stroke(Theme.Color.border, lineWidth: 0.5)
            )
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.smooth(duration: 0.15), value: configuration.isPressed)
    }
}

extension View {
    func cardStyle(highlighted: Bool = false) -> some View {
        modifier(CardStyle(highlighted: highlighted))
    }

    func chipStyle(tint: Color = Theme.Color.valid) -> some View {
        modifier(ChipStyle(tint: tint))
    }
}
