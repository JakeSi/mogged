import GameKit
import SwiftUI

struct GameCenterLeaderboardSheet: UIViewControllerRepresentable {
    @Binding var isPresented: Bool

    func makeUIViewController(context: Context) -> GKGameCenterViewController {
        let vc = GKGameCenterViewController(state: .leaderboards)
        vc.gameCenterDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: GKGameCenterViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(isPresented: $isPresented) }

    final class Coordinator: NSObject, GKGameCenterControllerDelegate {
        @Binding var isPresented: Bool
        init(isPresented: Binding<Bool>) { _isPresented = isPresented }

        func gameCenterViewControllerDidFinish(_ vc: GKGameCenterViewController) {
            isPresented = false
        }
    }
}
