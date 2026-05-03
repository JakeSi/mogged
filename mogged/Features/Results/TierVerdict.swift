import SwiftUI

struct TierVerdict: View {
    let tier: Tier
    let harmony: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text(tier.displayName)
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(Theme.Color.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
                Text(harmony, format: .number.precision(.fractionLength(1)))
                    .font(.system(size: 44, weight: .bold).monospacedDigit())
                    .foregroundStyle(Theme.Color.primaryText)
                    .contentTransition(.numericText())
            }
        }
    }
}
