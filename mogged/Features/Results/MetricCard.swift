import SwiftUI

struct MetricCard: View {
    let metric: Metric
    let score: Double
    var animateOnAppear: Bool = true

    @State private var displayScore: Double = 0

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ScoreRing(score: displayScore, size: 56, emphasized: metric == .harmony)

            VStack(alignment: .leading, spacing: 6) {
                Text(metric.displayName)
                    .font(AppType.cardTitle)
                    .foregroundStyle(Theme.Color.primaryText)

                Text(metric.tagline)
                    .font(AppType.caption)
                    .foregroundStyle(Theme.Color.secondaryText)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(highlighted: metric == .harmony)
        .onAppear {
            if animateOnAppear {
                withAnimation(.smooth(duration: 1.2)) {
                    displayScore = score
                }
            } else {
                displayScore = score
            }
        }
    }
}
