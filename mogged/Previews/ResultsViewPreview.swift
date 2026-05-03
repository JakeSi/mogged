import SwiftUI

#Preview("Results") {
    ResultsPreview()
}

private struct ResultsPreview: View {
    @State private var isExpanded = false

    private let metrics: [(Metric, Double)] = [
        (.canthalTilt, 8.1),
        (.jawWidth, 7.4),
        (.symmetry, 8.5),
        (.midface, 7.2),
        (.cheekbones, 7.9),
        (.eyeAspect, 6.8),
        (.verticalThirds, 7.6),
        (.fwhr, 8.0),
        (.jawForehead, 7.3),
        (.eyeSpacing, 7.7),
        (.noseLength, 6.9),
        (.chinProjection, 7.5),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    detailedResultsSection
                    actionRow
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(Theme.Gradient.pageBackdrop.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Image(systemName: "xmark")
                        .foregroundStyle(Theme.Color.primaryText)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.black.opacity(0.4)))
                }
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Image("AppIconImage")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                        Text("omoggle")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Theme.Color.primaryText)
                            .tracking(0.5)
                    }
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            Image("Preview2")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 110, height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Theme.Color.border, lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(Copy.Results.titleA)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Color.secondaryText)
                    .textCase(.uppercase)
                    .tracking(1)

                Text(Tier.chadlite.displayName)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Theme.Color.primaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)

                Text(7.82, format: .number.precision(.fractionLength(2)))
                    .font(.system(size: 72, weight: .bold))
                    .foregroundStyle(Theme.Gradient.ring)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var detailedResultsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Detailed Results")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.Color.secondaryText)
                .textCase(.uppercase)
                .tracking(1)

            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    ForEach(metrics, id: \.0) { metric, score in
                        MetricCard(metric: metric, score: score, animateOnAppear: false)
                    }
                }
                .frame(maxHeight: isExpanded ? .none : 200, alignment: .top)
                .clipped()
                .overlay(alignment: .bottom) {
                    if !isExpanded {
                        LinearGradient(
                            colors: [Theme.Color.background.opacity(0.25), Theme.Color.background],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 180)
                    }
                }

                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(isExpanded ? "Show Less" : "Show More")
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Color.secondaryText)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var actionRow: some View {
        Button(Copy.Results.scanAgain) {}
            .buttonStyle(PrimaryButtonStyle())
            .padding(.top, 8)
    }
}
