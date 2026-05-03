import SwiftUI

enum AppRoute: Hashable {
    case scan
    case results(ScanResult)
#if DEBUG
    case debug
#endif
}

struct AppRoot: View {
    @State private var path: [AppRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(
                onStartScan: { path.append(.scan) },
                onSelectResult: { result in path = [.results(result)] },
                onOpenDebug: {
#if DEBUG
                    path.append(.debug)
#endif
                }
            )
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .scan:
                        ScanView(
                            onComplete: { result in
                                path = [.results(result)]
                            },
                            onCancel: {
                                path.removeLast()
                            }
                        )
                        .toolbar(.hidden, for: .navigationBar)
                        .navigationBarBackButtonHidden(true)
                    case .results(let result):
                        ResultsView(
                            result: result,
                            onDismiss: { path.removeAll() },
                            onRescan: { path = [.scan] }
                        )
                        .navigationBarBackButtonHidden(true)
#if DEBUG
                    case .debug:
                        DebugView(
                            onComplete: { result in
                                path = [.results(result)]
                            },
                            onCancel: {
                                path.removeLast()
                            }
                        )
                        .toolbar(.hidden, for: .navigationBar)
                        .navigationBarBackButtonHidden(true)
#endif
                    }
                }
        }
    }
}
