import SwiftUI
import AVFoundation
import SwiftData

struct ScanView: View {
    let onComplete: (ScanResult) -> Void
    let onCancel: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var vm = ScanViewModel()
    @State private var previewLayer: AVCaptureVideoPreviewLayer?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if showsCamera {
                CameraPreview(session: vm.session, previewLayer: $previewLayer)
                    .ignoresSafeArea()
                    .overlay(
                        LandmarkOverlay(
                            landmarks: vm.liveLandmarks,
                            videoSize: vm.bufferSize,
                            previewLayer: previewLayer,
                            liveQuality: vm.liveQuality,
                            collectedFrames: vm.collectedFrames.count
                        )
                        .ignoresSafeArea()
                    )
                    .transition(.opacity)
            }

            noFaceOverlay

            VStack(spacing: 0) {
                scanProgressBar
                topBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                topTimerSection
                Spacer()
                bottomStack
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
            }

            stateOverlay
        }
        .preferredColorScheme(.dark)
        .task {
            vm.onComplete = { result in
                modelContext.insert(result)
                try? modelContext.save()
                onComplete(result)
            }
            await vm.begin()
        }
        .onDisappear {
            Task { await vm.cancel() }
        }
        .sensoryFeedback(.success, trigger: scanCompleteToken)
    }

    // MARK: - Pieces

    private var topBar: some View {
        HStack(alignment: .top) {
            Button {
                Task {
                    await vm.cancel()
                    onCancel()
                }
            } label: {
                Text(Copy.Scan.cancel)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.Color.primaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.black.opacity(0.5)))
            }

            Spacer()

            QualityBadges(faults: vm.liveQuality?.faults ?? [])
        }
    }

    @ViewBuilder
    private var scanProgressBar: some View {
        if case .scanning = vm.state {
            ScanProgressBar(progress: scanProgress)
                .transition(.opacity)
                .animation(.linear(duration: 0.05), value: scanProgress)
        }
    }

    @ViewBuilder
    private var topTimerSection: some View {
        if case .scanning = vm.state {
            ScanTimerHUD(countdown: vm.countdown, liveScore: vm.liveScore)
                .padding(.top, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    @ViewBuilder
    private var noFaceOverlay: some View {
        if case .scanning = vm.state, !vm.hasFace {
            Color.black.opacity(0.78)
                .ignoresSafeArea()
                .overlay(
                    VStack(spacing: 10) {
                        Image(systemName: "face.dashed")
                            .font(.system(size: 36, weight: .light))
                            .foregroundStyle(.white.opacity(0.6))
                        Text("No face detected")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                )
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: vm.hasFace)
        }
    }

    @ViewBuilder
    private var bottomStack: some View {
        EmptyView()
    }

    @ViewBuilder
    private var stateOverlay: some View {
        switch vm.state {
        case .awaitingUserConsent:
            ConsentOverlay {
                Task { await vm.continueFromConsent() }
            }
        case .idle, .requestingPermission, .starting:
            VStack(spacing: 12) {
                ProgressView().tint(.white)
                Text(Copy.Scan.loading)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.Color.secondaryText)
            }
            .padding(28)
        case .analyzing:
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView().tint(.white).scaleEffect(1.4)
                Text(Copy.Scan.analyzing)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.Color.secondaryText)
            }
            .transition(.opacity)
        case .denied:
            DeniedOverlay()
        case .failed(let reason):
            FailureOverlay(reason: reason, onRetry: {
                Task { await vm.retry() }
            }, onCancel: onCancel)
        case .complete:
            EmptyView()
        case .scanning:
            EmptyView()
        }
    }

    // MARK: - Derived

    private var showsCamera: Bool {
        switch vm.state {
        case .scanning, .analyzing, .starting: return true
        default: return false
        }
    }


    private var scanCompleteToken: Int {
        if case .complete = vm.state { return 1 }
        return 0
    }

    private var scanProgress: Double {
        guard case .scanning = vm.state else { return 0 }
        return 1.0 - (vm.countdown / vm.countdownDuration)
    }
}

// MARK: - Timer HUD

private struct ScanTimerHUD: View {
    let countdown: Double
    let liveScore: Double

    var body: some View {
        VStack(spacing: 6) {
            Text("SCORE")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color(white: 0.45))
                .tracking(2.5)

            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(String(format: "%.1f", liveScore))
                    .font(.system(size: 76, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.15), value: liveScore)
                    .shadow(color: .black.opacity(0.4), radius: 6, y: 3)

                Text("/ 10")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color(white: 0.55))
                    .padding(.bottom, 10)
            }
        }
    }
}

// MARK: - Consent / Denied / Failure overlays

private struct ConsentOverlay: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "camera")
                .font(.system(size: 72, weight: .regular))
                .foregroundStyle(.white)
                .padding(.bottom, 20)

            Text("Camera Access Required")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.bottom, 16)

            Text("This app needs your camera\nto evaluate your facial features.")
                .font(.system(size: 16))
                .foregroundStyle(Color(white: 0.55))
                .multilineTextAlignment(.center)
                .padding(.bottom, 48)

            Button("Continue", action: onContinue)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.yellow)
        }
        .padding(.horizontal, 20)
    }
}

private struct DeniedOverlay: View {
    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "camera")
                .font(.system(size: 80, weight: .regular))
                .foregroundStyle(.white)
                .padding(.bottom, 32)

            Text("Camera Access Required")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.bottom, 16)

            Text("Enable camera access in\nSettings to evaluate your facial features.")
                .font(.system(size: 17))
                .foregroundStyle(Color(white: 0.55))
                .multilineTextAlignment(.center)
                .padding(.bottom, 48)

            Button("Continue") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(Color.yellow)
        }
        .padding(.horizontal, 40)
    }
}

private struct FailureOverlay: View {
    let reason: String
    let onRetry: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text(Copy.Failure.title)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Theme.Color.primaryText)
            Text(reason)
                .font(.system(size: 13))
                .foregroundStyle(Theme.Color.secondaryText)
                .multilineTextAlignment(.center)
            Text(Copy.Failure.body)
                .font(.system(size: 13))
                .foregroundStyle(Theme.Color.tertiaryText)
                .multilineTextAlignment(.center)
            VStack(spacing: 10) {
                Button(Copy.Failure.retry, action: onRetry)
                    .buttonStyle(PrimaryButtonStyle())
                Button(Copy.Scan.cancel, action: onCancel)
                    .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding(24)
        .frame(maxWidth: 360)
        .cardStyle()
        .padding(20)
    }
}
