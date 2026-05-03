import Foundation
import Observation
import AVFoundation
import CoreMedia
import CoreVideo
import CoreImage
import UIKit
import simd

@Observable
@MainActor
final class ScanViewModel {

    enum State {
        case idle
        case awaitingUserConsent
        case requestingPermission
        case denied
        case starting
        case scanning
        case analyzing
        case complete(ScanResult)
        case failed(reason: String)
    }

    var state: State = .idle
    var liveQuality: FrameQuality?
    var liveLandmarks: [SIMD3<Float>] = []
    var liveScore: Double = 0
    var countdown: Double = 10
    var bufferSize: CGSize?
    var hasFace: Bool = false

    let countdownDuration: TimeInterval = 10.0
    let warmUpSeconds: TimeInterval = 0.8

    @ObservationIgnored
    private var rejectedFrameCount: Int = 0

    @ObservationIgnored
    private var rejectionFaultCounts: [Fault: Int] = [:]

    @ObservationIgnored
    var onComplete: ((ScanResult) -> Void)?

    @ObservationIgnored
    let camera = CameraSession()

    @ObservationIgnored
    private(set) var collectedFrames: [LandmarkFrame] = []

    @ObservationIgnored
    private(set) var collectedQualities: [FrameQuality] = []

    @ObservationIgnored
    private var provider: MediaPipeProvider?

    @ObservationIgnored
    private var consumingTask: Task<Void, Never>?

    @ObservationIgnored
    private var processingTask: Task<Void, Never>?

    @ObservationIgnored
    private var countdownTask: Task<Void, Never>?

    @ObservationIgnored
    private var faceDetectedAt: Date?

    @ObservationIgnored
    private var latestPixelBuffer: CVPixelBuffer?

    var session: AVCaptureSession { camera.session }

    // MARK: - Public

    func begin() async {
        guard case .idle = state else { return }
        switch CameraPermission.status {
        case .authorized:
            await startScan()
        case .notDetermined:
            state = .awaitingUserConsent
        case .denied, .restricted:
            state = .denied
        @unknown default:
            state = .denied
        }
    }

    func continueFromConsent() async {
        guard case .awaitingUserConsent = state else { return }

        switch CameraPermission.status {
        case .authorized:
            await startScan()
        case .notDetermined:
            state = .requestingPermission
            let granted = await CameraPermission.request()
            if granted { await startScan() } else { state = .denied }
        case .denied, .restricted:
            state = .denied
        @unknown default:
            state = .denied
        }
    }

    func cancel() async {
        AppAnalytics.scanCancelled()
        await teardown()
        state = .idle
    }

    func retry() async {
        AppAnalytics.scanRetried()
        await teardown()
        collectedFrames.removeAll()
        collectedQualities.removeAll()
        liveLandmarks = []
        liveQuality = nil
        liveScore = 0
        countdown = countdownDuration
        faceDetectedAt = nil
        latestPixelBuffer = nil
        rejectedFrameCount = 0
        rejectionFaultCounts = [:]
        hasFace = false
        state = .awaitingUserConsent
        await continueFromConsent()
    }

    // MARK: - Pipeline

    private func startScan() async {
        do {
            let provider = try MediaPipeProvider(targetFPS: 15)
            self.provider = provider
            // Get a fresh stream before starting the camera so the old processingTask's
            // for-await exits cleanly (makeBufferStream finishes the previous continuation).
            let buffers = camera.makeBufferStream()
            try await camera.start()
            AppAnalytics.scanStarted()
            countdown = countdownDuration
            state = .starting
            startProcessingLoop(provider: provider, buffers: buffers)
            startConsumingLoop(provider: provider)
        } catch {
            state = .failed(reason: (error as? LocalizedError)?.errorDescription ?? "\(error)")
        }
    }

    private func startProcessingLoop(provider: MediaPipeProvider, buffers: AsyncStream<CMSampleBuffer>) {
        processingTask = Task.detached(priority: .userInitiated) { [weak self] in
            var reportedSize: CGSize?
            var bufferCount = 0
            for await buffer in buffers {
                if Task.isCancelled { break }
                bufferCount += 1
                if bufferCount == 1 { print("[Scan] First camera buffer received") }
                if bufferCount % 30 == 0 { print("[Scan] Camera buffers received: \(bufferCount)") }
                if let pixelBuffer = CMSampleBufferGetImageBuffer(buffer) {
                    let size = CGSize(
                        width: CVPixelBufferGetWidth(pixelBuffer),
                        height: CVPixelBufferGetHeight(pixelBuffer)
                    )
                    let pb = pixelBuffer
                    if size != reportedSize {
                        reportedSize = size
                        await MainActor.run { [weak self] in
                            self?.bufferSize = size
                        }
                    }
                    await MainActor.run { [weak self] in
                        self?.latestPixelBuffer = pb
                    }
                }
                await provider.process(buffer: buffer, orientation: .up)
            }
        }
    }

    private func startConsumingLoop(provider: MediaPipeProvider) {
        consumingTask = Task { [weak self] in
            var prev: LandmarkFrame?
            var frameCount = 0
            for await frame in provider.frames {
                guard let self else { break }
                if Task.isCancelled { break }
                frameCount += 1
                if frameCount == 1 { print("[Scan] First landmark frame received, hasFace=\(frame.hasFace)") }
                let q = QualityGate.evaluate(frame: frame, previous: prev)
                if frameCount <= 5 || frameCount % 15 == 0 {
                    print("[Scan] Frame \(frameCount): hasFace=\(frame.hasFace) conf=\(String(format: "%.2f", q.confidence)) rel=\(String(format: "%.2f", q.reliability)) valid=\(q.isValid) faults=\(q.faults.map(\.rawValue))")
                }
                self.handleFrame(frame, quality: q)
                prev = frame
            }
            print("[Scan] Consumer loop ended, total frames: \(frameCount)")
        }
    }

    private func handleFrame(_ frame: LandmarkFrame, quality: FrameQuality) {
        liveLandmarks = frame.landmarks
        liveQuality = quality
        hasFace = frame.hasFace

        switch state {
        case .starting:
            guard frame.hasFace else { return }
            faceDetectedAt = .now
            liveScore = computeLiveScore(frame: frame)
            startCountdown()
            state = .scanning
        case .scanning:
            liveScore = computeLiveScore(frame: frame)
        default:
            return
        }

        guard let detected = faceDetectedAt, Date().timeIntervalSince(detected) > warmUpSeconds else { return }

        if quality.isValid {
            collectedFrames.append(frame)
            collectedQualities.append(quality)
            if collectedFrames.count == 1 { print("[Scan] First valid frame collected") }
        } else {
            rejectedFrameCount += 1
            for fault in quality.faults { rejectionFaultCounts[fault, default: 0] += 1 }
            if rejectedFrameCount > 15 {
                abortFromRejections()
                return
            }
            print("[Scan] Frame rejected (\(rejectedFrameCount)/15): conf=\(String(format: "%.2f", quality.confidence)) rel=\(String(format: "%.2f", quality.reliability)) faults=\(quality.faults.map(\.rawValue))")
        }
    }

    private func abortFromRejections() {
        guard case .scanning = state else { return }
        countdownTask?.cancel()
        countdownTask = nil
        let topFaults = rejectionFaultCounts.sorted { $0.value > $1.value }.prefix(3).map(\.key)
        let reason: String
        if topFaults.first == .noFace {
            reason = "Face lost too often. Keep your face clearly in frame and try again."
        } else if topFaults.isEmpty {
            reason = "Too many frames were rejected. Ensure good lighting and hold still."
        } else {
            let labels = topFaults.map(\.label).joined(separator: " · ")
            reason = "Too many frames rejected — \(labels)."
        }
        AppAnalytics.scanFailed(reason: "aborted: \(topFaults.map(\.rawValue).joined(separator: ","))")
        state = .failed(reason: reason)
    }

    private func startCountdown() {
        countdown = countdownDuration
        let start = Date.now
        let duration = countdownDuration
        countdownTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { break }
                let elapsed = Date.now.timeIntervalSince(start)
                let remaining = max(0, duration - elapsed)
                self.countdown = remaining
                if remaining <= 0 {
                    await self.finalize()
                    break
                }
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
    }

    private func computeLiveScore(frame: LandmarkFrame) -> Double {
        var raw: [Metric: Double] = [:]
        for metric in Metric.allCases where metric != .harmony {
            if let v = Aggregator.rawValue(of: metric, in: frame) {
                raw[metric] = v
            }
        }
        let agg = ScanAggregate(rawMetrics: raw, avgConfidence: 1, avgReliability: 1, validFrames: 1)
        let (_, harmony, _) = HarmonyEngine.finalize(aggregate: agg)
        return harmony
    }

    private func captureCurrentFrame() -> Data? {
        guard let pixelBuffer = latestPixelBuffer else { return nil }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        let uiImage = UIImage(cgImage: cgImage)
        return uiImage.cappedThumbnail(maxDimension: 400)
    }

    private func finalize() async {
        state = .analyzing
        countdownTask?.cancel()
        countdownTask = nil

        // Capture thumbnail before stopping camera, then stop MediaPipe immediately.
        let thumbnailData = captureCurrentFrame()
        let frames = Array(collectedFrames.suffix(10))
        let qualities = Array(collectedQualities.suffix(10))
        await teardown()

        print("[Scan] Finalizing: using last \(frames.count) of \(collectedFrames.count) valid frames")
        guard !frames.isEmpty else {
            print("[Scan] FAILED — collectedQualities summary: \(qualities.prefix(5).map { "c:\(String(format: "%.2f", $0.confidence)) r:\(String(format: "%.2f", $0.reliability)) \($0.faults.map(\.rawValue))" })")
            let failReason = "No frames captured. Keep your face visible during the countdown."
            AppAnalytics.scanFailed(reason: failReason)
            state = .failed(reason: failReason)
            return
        }

        do {
            let aggregate = try await Task.detached(priority: .userInitiated) {
                try Aggregator.aggregate(frames: frames, qualities: qualities)
            }.value
            let result = HarmonyEngine.makeResult(aggregate: aggregate, thumbnail: thumbnailData)
            AppAnalytics.scanCompleted(result: result)
            state = .complete(result)
            onComplete?(result)
        } catch {
            let msg = (error as? LocalizedError)?.errorDescription ?? Copy.Failure.body
            AppAnalytics.scanFailed(reason: msg)
            state = .failed(reason: msg)
        }
    }

    private func teardown() async {
        countdownTask?.cancel()
        countdownTask = nil

        // Capture refs before clearing — we need to await them after cancellation.
        let pTask = processingTask
        let cTask = consumingTask
        processingTask = nil
        consumingTask = nil

        pTask?.cancel()
        cTask?.cancel()

        // Stop the camera then finish the buffer stream so processingTask's for-await exits.
        await camera.stop()
        camera.finishStream()

        // Wait for processingTask to exit — guarantees no more detectAsync() calls are in flight.
        _ = await pTask?.value

        // Drain in-flight MediaPipe inferences before closing the stream.
        // finish() waits for the last submitted callback (up to 500ms) so FaceLandmarker
        // is not deallocated while GenerateOutputPacketMap is still running.
        await provider?.finish()

        // Wait for consumingTask to fully drain.
        _ = await cTask?.value

        provider = nil
    }
}
