import SwiftUI

struct QualityGatePanel: View {
    let confidence: Double
    let reliability: Double
    let validFrames: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            EyebrowLabel(text: Copy.Results.qualityGate)

            VStack(spacing: 0) {
                row(label: Copy.Results.reliability, value: String(format: "≥ %.2f", 0.68))
                divider
                row(label: Copy.Results.confidence, value: String(format: "≥ %.2f", 0.72))
                divider
                row(label: Copy.Results.trimMean, value: "18%")
                divider
                row(label: Copy.Results.frames, value: "\(validFrames)/\(30)")
            }

            Spacer(minLength: 0)

            Text(Copy.Results.qualityFooter)
                .font(AppType.caption)
                .foregroundStyle(Theme.Color.secondaryText)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 200, alignment: .topLeading)
        .cardStyle()
    }

    private func row(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(AppType.body)
                .foregroundStyle(Theme.Color.secondaryText)
            Spacer()
            Text(value)
                .font(AppType.bodyEmphasis.monospacedDigit())
                .foregroundStyle(Theme.Color.primaryText)
        }
        .padding(.vertical, 8)
    }

    private var divider: some View {
        Rectangle()
            .fill(Theme.Color.border)
            .frame(height: 0.5)
    }
}
