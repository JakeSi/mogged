import SwiftUI

struct ScanProgressBar: View {
    var progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Spacer()
                Text("\(Int(ceil((1.0 - progress) * 10)))s")
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Theme.Color.secondaryText)
                    .contentTransition(.numericText())
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.10))
                    Capsule()
                        .fill(Color.white)
                        .frame(width: max(2, proxy.size.width * (1.0 - progress)))
                        .animation(.smooth(duration: 0.35), value: progress)
                }
            }
            .frame(height: 4)
        }
        .padding(.horizontal, 4)
    }
}
