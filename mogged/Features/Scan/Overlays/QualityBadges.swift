import SwiftUI

struct QualityBadges: View {
    var faults: [Fault]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(prioritized(), id: \.self) { fault in
                Text(fault.label)
                    .chipStyle(tint: tint(for: fault))
            }
        }
        .animation(.smooth(duration: 0.25), value: faults)
    }

    private func prioritized() -> [Fault] {
        // Show invalid first, then warnings, capped to 2 to avoid clutter.
        let sorted = faults.sorted { lhs, rhs in
            lhs.severity == .invalid && rhs.severity != .invalid
        }
        return Array(sorted.prefix(2))
    }

    private func tint(for fault: Fault) -> Color {
        switch fault.severity {
        case .invalid: return Theme.Color.invalid
        case .warning: return Theme.Color.warning
        }
    }
}
