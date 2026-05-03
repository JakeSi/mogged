import SwiftUI
import SwiftData

struct HomeView: View {
    let onStartScan: () -> Void
    let onSelectResult: (ScanResult) -> Void
    let onOpenDebug: () -> Void

    @State private var profileOpen = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Theme.Color.background.ignoresSafeArea()
            Theme.Gradient.pageBackdrop.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    mascot
                    tagline
                    buttons
                    Spacer(minLength: 60)
                }
                .padding(.horizontal, 24)
                .padding(.top, 60)
            }

            historyButton
                .padding(.horizontal, 16)
                .padding(.top, 12)
        }
        .sheet(isPresented: $profileOpen) {
            ProfileSheet(
                onClose: { profileOpen = false },
                onSelectResult: { result in
                    profileOpen = false
                    onSelectResult(result)
                }
            )
        }
        .preferredColorScheme(.dark)
        .task {
            let count = UserDefaults.standard.integer(forKey: "completedGameCount")
            guard count >= 1 else { return }
            await NotificationManager.shared.requestPermissionIfNeeded()
        }
    }

    // MARK: - Pieces

    private var mascot: some View {
        Image("Mascot")
            .resizable()
            .scaledToFit()
            .frame(maxWidth: 280)
            .accessibilityHidden(true)
    }

    private var tagline: some View {
        Text("MOG OR GET MOGGED")
            .font(.system(size: 32, weight: .black))
            .tracking(1.5)
            .multilineTextAlignment(.center)
            .foregroundStyle(Theme.Color.primaryText)
    }

    private var buttons: some View {
        VStack(spacing: 12) {
            Button("Play", action: onStartScan)
                .buttonStyle(PrimaryButtonStyle())

            Button(action: {}) {
                HStack(spacing: 8) {
                    Text("⚔️ Battle")
                    Text("(Coming Soon...)")
                        .font(.system(size: 12, weight: .semibold))
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(true)
            .opacity(0.3)
        }
    }


    private var historyButton: some View {
        Button { profileOpen = true } label: {
            Image(systemName: "person.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.Color.primaryText)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.black.opacity(0.5)))
                .overlay(Circle().stroke(Theme.Color.border, lineWidth: 0.5))
        }
        .accessibilityLabel("Profile")
        .simultaneousGesture(
            LongPressGesture().onEnded { _ in
#if DEBUG
                onOpenDebug()
#endif
            }
        )
    }
}


private extension Date {
    static func relativeShort(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}
