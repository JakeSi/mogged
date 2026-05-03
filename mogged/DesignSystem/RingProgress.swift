import SwiftUI

struct RingProgress: View {
    /// 0.0 ... 1.0
    var progress: Double
    var lineWidth: CGFloat = 3.5
    var trackOpacity: Double = 1.0

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.Gradient.ringTrack, lineWidth: lineWidth)
                .opacity(trackOpacity)

            Circle()
                .trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(
                    Theme.Gradient.ring,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.smooth(duration: 1.4), value: progress)
        }
    }
}

struct ScoreRing: View {
    /// 0.0 ... 10.0
    var score: Double
    var size: CGFloat = 64
    var emphasized: Bool = false

    var body: some View {
        ZStack {
            RingProgress(progress: score / 10.0, lineWidth: emphasized ? 4 : 3.5)
                .frame(width: size, height: size)

            Text(score, format: .number.precision(.fractionLength(1)))
                .font(.system(size: size * 0.34, weight: .bold).monospacedDigit())
                .foregroundStyle(Theme.Color.primaryText)
                .contentTransition(.numericText())
        }
    }
}
