import SwiftUI
import SwiftData

struct HistorySheet: View {
    let onClose: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ScanResult.date, order: .reverse) private var results: [ScanResult]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Color.background.ignoresSafeArea()

                if results.isEmpty {
                    VStack(spacing: 8) {
                        Text(Copy.History.empty)
                            .font(AppType.body)
                            .foregroundStyle(Theme.Color.secondaryText)
                    }
                    .padding(40)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(results, id: \.persistentModelID) { result in
                                HistoryRow(result: result)
                            }
                            .onDelete(perform: delete)
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle(Copy.History.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(Copy.History.close, action: onClose)
                        .foregroundStyle(Theme.Color.primaryText)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(results[index])
        }
        try? modelContext.save()
    }
}

private struct HistoryRow: View {
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
        }
        .padding(14)
        .cardStyle()
    }
}
