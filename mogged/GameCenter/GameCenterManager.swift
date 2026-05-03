import GameKit

// Leaderboard IDs — create these in App Store Connect (Leaderboards section)
// and replace these placeholder strings with your actual IDs.
private let kAllTimeLeaderboardID = "mogged.leaderboard.alltime"
private let kDailyLeaderboardID   = "mogged.leaderboard.daily"

@MainActor
@Observable
final class GameCenterManager {
    private(set) var isAuthenticated = false
    private(set) var isLoadingRank   = false
    private(set) var personalBest: Double?   // harmony in 0–10 range
    private(set) var allTimeRank: Int?
    private(set) var dailyRank: Int?

    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { _, _ in
            Task { @MainActor [weak self] in
                self?.isAuthenticated = GKLocalPlayer.local.isAuthenticated
            }
        }
    }

    // Submits harmony score (stored as integer = harmony × 100) to both leaderboards,
    // then loads the player's rank and personal best.
    func submitAndLoadRank(harmony: Double) async {
        guard GKLocalPlayer.local.isAuthenticated else { return }

        isLoadingRank = true
        allTimeRank   = nil
        dailyRank     = nil
        personalBest  = nil

        defer { isLoadingRank = false }

        let gcScore = Int((harmony * 100).rounded())

        await withCheckedContinuation { continuation in
            GKLeaderboard.submitScore(
                gcScore,
                context: 0,
                player: GKLocalPlayer.local,
                leaderboardIDs: [kAllTimeLeaderboardID, kDailyLeaderboardID]
            ) { _ in continuation.resume() }
        }

        async let atEntry    = loadPlayerEntry(leaderboardID: kAllTimeLeaderboardID, timeScope: .allTime)
        async let dailyEntry = loadPlayerEntry(leaderboardID: kDailyLeaderboardID,   timeScope: .today)
        let (at, daily)      = await (atEntry, dailyEntry)

        allTimeRank  = at?.rank
        dailyRank    = daily?.rank
        personalBest = at.map { Double($0.score) / 100 }
    }

    func loadRank() async {
        guard GKLocalPlayer.local.isAuthenticated else { return }
        isLoadingRank = true
        defer { isLoadingRank = false }

        async let atEntry    = loadPlayerEntry(leaderboardID: kAllTimeLeaderboardID, timeScope: .allTime)
        async let dailyEntry = loadPlayerEntry(leaderboardID: kDailyLeaderboardID,   timeScope: .today)
        let (at, daily)      = await (atEntry, dailyEntry)

        allTimeRank  = at?.rank
        dailyRank    = daily?.rank
        personalBest = at.map { Double($0.score) / 100 }
    }

    nonisolated private func loadPlayerEntry(
        leaderboardID: String,
        timeScope: GKLeaderboard.TimeScope
    ) async -> GKLeaderboard.Entry? {
        do {
            let leaderboards: [GKLeaderboard] = try await withCheckedThrowingContinuation { cont in
                GKLeaderboard.loadLeaderboards(IDs: [leaderboardID]) { lbs, err in
                    if let err { cont.resume(throwing: err) }
                    else { cont.resume(returning: lbs ?? []) }
                }
            }
            guard let lb = leaderboards.first else { return nil }
            return try await withCheckedThrowingContinuation { cont in
                lb.loadEntries(for: [GKLocalPlayer.local], timeScope: timeScope) { local, _, err in
                    if let err { cont.resume(throwing: err) }
                    else { cont.resume(returning: local) }
                }
            }
        } catch {
            return nil
        }
    }
}
