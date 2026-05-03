import SwiftUI
import SwiftData

struct ProfileSheet: View {
    let onClose: () -> Void
    let onSelectResult: (ScanResult) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(GameCenterManager.self) private var gcManager
    @Query(sort: \ScanResult.date, order: .reverse) private var results: [ScanResult]
    @State private var showLeaderboards = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Color.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if gcManager.isAuthenticated {
                            statsCard
                            leaderboardsButton
                        }
                        historySection
                    }
                    .padding(20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(Copy.History.close, action: onClose)
                        .foregroundStyle(Theme.Color.primaryText)
                }
            }
        }
        .preferredColorScheme(.dark)
        .task { await gcManager.loadRank() }
        .fullScreenCover(isPresented: $showLeaderboards) {
            GameCenterLeaderboardSheet(isPresented: $showLeaderboards)
                .ignoresSafeArea()
        }
    }

    // MARK: - Stats

    private var statsCard: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                EyebrowLabel(text: Copy.GameCenter.personalBest)
                Group {
                    if gcManager.isLoadingRank {
                        Text("—")
                            .foregroundStyle(Theme.Color.tertiaryText)
                    } else if let pb = gcManager.personalBest {
                        Text(pb, format: .number.precision(.fractionLength(2)))
                            .foregroundStyle(Theme.Gradient.ring)
                            .contentTransition(.numericText())
                    } else {
                        Text("—")
                            .foregroundStyle(Theme.Color.tertiaryText)
                    }
                }
                .font(.system(size: 64, weight: .bold).monospacedDigit())
            }

            Theme.Color.border.frame(height: 0.5)

            HStack(spacing: 0) {
                rankColumn(label: Copy.GameCenter.daily, rank: gcManager.dailyRank)
                Theme.Color.border.frame(width: 0.5, height: 44)
                rankColumn(label: Copy.GameCenter.allTime, rank: gcManager.allTimeRank)
            }
        }
        .padding(20)
        .cardStyle()
    }

    private func rankColumn(label: String, rank: Int?) -> some View {
        VStack(spacing: 4) {
            EyebrowLabel(text: label)
            Group {
                if gcManager.isLoadingRank {
                    Text("—")
                        .foregroundStyle(Theme.Color.tertiaryText)
                } else if let rank {
                    Text("#\(rank)")
                        .foregroundStyle(Theme.Color.primaryText)
                        .contentTransition(.numericText())
                } else {
                    Text("—")
                        .foregroundStyle(Theme.Color.tertiaryText)
                }
            }
            .font(.system(size: 32, weight: .bold).monospacedDigit())
        }
        .frame(maxWidth: .infinity)
    }

    private var leaderboardsButton: some View {
        Button {
            showLeaderboards = true
        } label: {
            Label(Copy.GameCenter.viewLeaderboards, systemImage: "list.number")
        }
        .buttonStyle(SecondaryButtonStyle())
    }

    // MARK: - History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            EyebrowLabel(text: Copy.History.title)

            if results.isEmpty {
                Text(Copy.History.empty)
                    .font(AppType.body)
                    .foregroundStyle(Theme.Color.secondaryText)
                    .padding(.top, 12)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(results, id: \.persistentModelID) { result in
                        Button { onSelectResult(result) } label: {
                            ProfileHistoryRow(result: result)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

// MARK: - History Row

private struct ProfileHistoryRow: View {
    let result: ScanResult

    var body: some View {
        HStack(spacing: 16) {
            ScoreRing(score: result.harmony, size: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text(result.tier.displayName)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.Color.primaryText)
                Text(result.date, format: .dateTime.month().day().hour().minute())
                    .font(AppType.caption)
                    .foregroundStyle(Theme.Color.tertiaryText)
            }

            Spacer(minLength: 0)

            Text(result.harmony, format: .number.precision(.fractionLength(2)))
                .font(.system(size: 20, weight: .bold).monospacedDigit())
                .foregroundStyle(Theme.Color.primaryText)
        }
        .padding(14)
        .cardStyle()
    }
}
