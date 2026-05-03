import SwiftUI
import SwiftData
import StoreKit
import UIKit

struct ResultsView: View {
    let result: ScanResult
    let onDismiss: () -> Void
    let onRescan: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(GameCenterManager.self) private var gcManager
    @Environment(\.requestReview) private var requestReview
    @State private var didSave: Bool = false
    @State private var showLeaderboards = false
    @State private var isExpanded = false


    var body: some View {
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
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .foregroundStyle(Theme.Color.primaryText)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.black.opacity(0.4)))
                }
            }
            ToolbarItem(placement: .principal) {
                brandHeader
            }
        }
        .preferredColorScheme(.dark)
        .task { await gcManager.submitAndLoadRank(harmony: result.harmony) }
        .task { await maybeRequestReview() }
        .fullScreenCover(isPresented: $showLeaderboards) {
            GameCenterLeaderboardSheet(isPresented: $showLeaderboards)
                .ignoresSafeArea()
        }
    }

    // MARK: - Pieces

    private var brandHeader: some View {
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

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            if let data = result.thumbnail, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 110, height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Theme.Color.border, lineWidth: 1)
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(Copy.Results.titleA)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Color.secondaryText)
                    .textCase(.uppercase)
                    .tracking(1)

                Text(result.tier.displayName)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Theme.Color.primaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .fixedSize(horizontal: false, vertical: true)

                Text(result.harmony, format: .number.precision(.fractionLength(2)))
                    .font(.system(size: 72, weight: .bold))
                    .foregroundStyle(Theme.Gradient.ring)
                    .contentTransition(.numericText())

                rankRow
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var rankRow: some View {
        if gcManager.isAuthenticated {
            if gcManager.isLoadingRank {
                Text(Copy.GameCenter.loading)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.Color.secondaryText)
            } else if gcManager.allTimeRank != nil || gcManager.personalBest != nil {
                HStack(spacing: 6) {
                    if let pb = gcManager.personalBest {
                        rankChip(label: Copy.GameCenter.personalBestShort,
                                 value: String(format: "%.2f", pb))
                    }
                    if let at = gcManager.allTimeRank {
                        rankChip(label: Copy.GameCenter.allTime, value: "#\(at)")
                    }
                }
            }
        }
    }

    private func rankChip(label: String, value: String) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Theme.Color.secondaryText)
                .textCase(.uppercase)
                .tracking(0.5)
            Text(value)
                .font(.system(size: 11, weight: .bold).monospacedDigit())
                .foregroundStyle(Theme.Color.primaryText)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.07))
        .clipShape(Capsule())
    }

    private var detailedResultsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Detailed Results")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.Color.secondaryText)
                .textCase(.uppercase)
                .tracking(1)

            VStack(spacing: 0) {
                list
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

    private var list: some View {
        VStack(spacing: 12) {
            ForEach(Metric.allCases.filter { $0 != .harmony }, id: \.self) { metric in
                MetricCard(metric: metric, score: result.score(for: metric))
            }
        }
    }

    private var actionRow: some View {
        VStack(spacing: 10) {
            Button(action: onRescan) {
                Text(Copy.Results.scanAgain)
            }
            .buttonStyle(PrimaryButtonStyle())


            if gcManager.isAuthenticated {
                Button {
                    AppAnalytics.leaderboardViewed()
                    showLeaderboards = true
                } label: {
                    Label(Copy.GameCenter.viewLeaderboards, systemImage: "list.number")
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Actions

    private func maybeRequestReview() async {
        let key = "completedGameCount"
        let count = UserDefaults.standard.integer(forKey: key) + 1
        UserDefaults.standard.set(count, forKey: key)

        await NotificationManager.shared.scheduleReengagement()

        guard count == 1 || count == 10 || count == 25 else { return }
        try? await Task.sleep(for: .seconds(1))
        requestReview()
    }

    private func saveIfNeeded() {
        guard !didSave else { return }
        if result.modelContext == nil {
            modelContext.insert(result)
        }
        try? modelContext.save()
        AppAnalytics.resultSaved()
        withAnimation(.smooth(duration: 0.2)) { didSave = true }
    }

}
