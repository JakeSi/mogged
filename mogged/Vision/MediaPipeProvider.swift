import Foundation
import CoreMedia
import CoreVideo
import UIKit
import MediaPipeTasksVision

/// Bridges the FaceLandmarker live-stream delegate (called on a private serial dispatch queue)
/// into an AsyncStream<LandmarkFrame>. Holds the per-frame luma map so we can pair input lightness
/// with output landmarks.
nonisolated final class FaceLandmarkerBridge: NSObject, FaceLandmarkerLiveStreamDelegate, @unchecked Sendable {
    private let continuation: AsyncStream<LandmarkFrame>.Continuation
    private let lumaLock = NSLock()
    private var pendingLuma: [Int: Float] = [:]

    // Drain: wait until MediaPipe fires a callback for a given timestamp before
    // allowing FaceLandmarker to be deallocated.
    private let drainLock = NSLock()
    private var lastReceivedTimestampMs: Int = -1
    private var drainTarget: Int? = nil
    private var drainContinuation: CheckedContinuation<Void, Never>? = nil

    init(continuation: AsyncStream<LandmarkFrame>.Continuation) {
        self.continuation = continuation
        super.init()
    }

    func setLuma(_ luma: Float, for timestampMs: Int) {
        lumaLock.lock()
        pendingLuma[timestampMs] = luma
        // Cap the table so a stuck inference doesn't leak memory forever.
        if pendingLuma.count > 60 {
            let oldest = pendingLuma.keys.sorted().prefix(pendingLuma.count - 60)
            for k in oldest { pendingLuma.removeValue(forKey: k) }
        }
        lumaLock.unlock()
    }

    private func popLuma(for timestampMs: Int) -> Float {
        lumaLock.lock()
        defer { lumaLock.unlock() }
        return pendingLuma.removeValue(forKey: timestampMs) ?? 0.5
    }

    func finish() {
        continuation.finish()
    }

    /// Suspends until MediaPipe delivers a callback with timestamp >= `ts`,
    /// or until the caller races it with a timeout task.
    func waitForCallbackTimestamp(_ ts: Int) async {
        guard ts > 0 else { return }
        await withCheckedContinuation { cont in
            drainLock.lock()
            if lastReceivedTimestampMs >= ts {
                drainLock.unlock()
                cont.resume()
                return
            }
            drainTarget = ts
            drainContinuation = cont
            drainLock.unlock()
        }
    }

    // MARK: FaceLandmarkerLiveStreamDelegate

    func faceLandmarker(
        _ faceLandmarker: FaceLandmarker,
        didFinishDetection result: FaceLandmarkerResult?,
        timestampInMilliseconds: Int,
        error: Error?
    ) {
        // Resolve drain before touching the continuation so the caller can observe
        // that MediaPipe has fully returned from this inference before deallocation.
        drainLock.lock()
        lastReceivedTimestampMs = timestampInMilliseconds
        let drainCont: CheckedContinuation<Void, Never>?
        if let target = drainTarget, timestampInMilliseconds >= target {
            drainCont = drainContinuation
            drainTarget = nil
            drainContinuation = nil
        } else {
            drainCont = nil
        }
        drainLock.unlock()
        drainCont?.resume()

        let luma = popLuma(for: timestampInMilliseconds)

        guard let result, let face = result.faceLandmarks.first else {
            continuation.yield(LandmarkFrame.empty(timestampMs: timestampInMilliseconds, luma: luma))
            return
        }

        var points: [SIMD3<Float>] = []
        points.reserveCapacity(face.count)
        for lm in face {
            points.append(SIMD3(lm.x, lm.y, lm.z))
        }

        var blendshapeSum: Float = 0
        if let bs = result.faceBlendshapes.first {
            for category in bs.categories {
                blendshapeSum += category.score
            }
        }

        let frame = LandmarkFrame(
            landmarks: points,
            blendshapeSum: blendshapeSum,
            timestampMs: timestampInMilliseconds,
            imageLuma: luma
        )
        continuation.yield(frame)
    }
}

/// Concrete face landmark provider backed by MediaPipe Tasks Vision.
actor MediaPipeProvider: FaceLandmarkProvider {
    private let landmarker: FaceLandmarker
    private let bridge: FaceLandmarkerBridge

    nonisolated let frames: AsyncStream<LandmarkFrame>

    private var lastSubmittedAt: TimeInterval = 0
    private let throttleSeconds: TimeInterval
    private var lastSubmittedTimestampMs: Int = 0

    enum ProviderError: Error {
        case modelNotFound
    }

    init(targetFPS: Double = 15) throws {
        guard let modelPath = Bundle.main.path(forResource: "face_landmarker", ofType: "task") else {
            throw ProviderError.modelNotFound
        }
        self.throttleSeconds = 1.0 / max(1.0, targetFPS)

        var contRef: AsyncStream<LandmarkFrame>.Continuation!
        self.frames = AsyncStream<LandmarkFrame>(bufferingPolicy: .bufferingNewest(4)) { continuation in
            contRef = continuation
        }

        let bridge = FaceLandmarkerBridge(continuation: contRef)
        self.bridge = bridge

        let options = FaceLandmarkerOptions()
        options.baseOptions.modelAssetPath = modelPath
        options.baseOptions.delegate = .CPU
        options.runningMode = .liveStream
        options.numFaces = 1
        options.outputFaceBlendshapes = true
        options.outputFacialTransformationMatrixes = true
        options.minFaceDetectionConfidence = 0.5
        options.minFacePresenceConfidence = 0.5
        options.minTrackingConfidence = 0.5
        options.faceLandmarkerLiveStreamDelegate = bridge

        self.landmarker = try FaceLandmarker(options: options)
    }

    func process(buffer: CMSampleBuffer, orientation: UIImage.Orientation) {
        let now = Date().timeIntervalSinceReferenceDate
        guard (now - lastSubmittedAt) >= throttleSeconds else { return }
        lastSubmittedAt = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(buffer) else { return }
        let luma = MeanLuma.compute(pixelBuffer: pixelBuffer)

        let mpImage: MPImage
        do {
            mpImage = try MPImage(sampleBuffer: buffer, orientation: orientation)
        } catch {
            return
        }

        let timestampMs = Int(now * 1000)
        bridge.setLuma(luma, for: timestampMs)

        do {
            try landmarker.detectAsync(image: mpImage, timestampInMilliseconds: timestampMs)
            lastSubmittedTimestampMs = timestampMs
        } catch {
            // dropped frame; we'll get the next one
        }
    }

    /// Waits for MediaPipe to deliver the callback for the last submitted inference,
    /// then closes the landmark stream. This prevents deallocation of FaceLandmarker
    /// while its C++ thread pool is still mid-inference (EXC_BAD_ACCESS in GenerateOutputPacketMap).
    func finish() async {
        let ts = lastSubmittedTimestampMs
        if ts > 0 {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.bridge.waitForCallbackTimestamp(ts) }
                group.addTask { try? await Task.sleep(for: .milliseconds(500)) }
                _ = await group.next()
                group.cancelAll()
            }
        }
        bridge.finish()
    }
}
