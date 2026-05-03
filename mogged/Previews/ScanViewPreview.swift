import SwiftUI

#Preview("Scan") {
    ScanViewPreview()
}

struct ScanViewPreview: View {
    var body: some View {
        ZStack {
            Image("Preview1")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ScanProgressBar(progress: 0.45)

                HStack(alignment: .top) {
                    Text(Copy.Scan.cancel)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.Color.primaryText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.black.opacity(0.5)))
                        .padding(.horizontal, 8)
                    Spacer()
                    QualityBadges(faults: [])
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                PreviewTimerHUD(liveScore: 8.9)
                    .padding(.top, 12)

                Spacer()
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct PreviewTimerHUD: View {
    let liveScore: Double

    var body: some View {
        VStack(spacing: 6) {
            Text("SCORE")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color(white: 0.45))
                .tracking(2.5)

            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(String(format: "%.1f", liveScore))
                    .font(.system(size: 76, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 6, y: 3)

                Text("/ 10")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color(white: 0.55))
                    .padding(.bottom, 10)
            }
        }
    }
}
