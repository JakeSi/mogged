import Foundation
import AVFoundation
import CoreMedia

/// Bridges AVCaptureVideoDataOutputSampleBufferDelegate (called on a private queue) into an AsyncStream.
/// The continuation can be swapped atomically to support multiple scan cycles on the same session.
nonisolated final class VideoOutputBridge: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: AsyncStream<CMSampleBuffer>.Continuation?

    func setContinuation(_ cont: AsyncStream<CMSampleBuffer>.Continuation) {
        lock.lock()
        continuation?.finish()
        continuation = cont
        lock.unlock()
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        lock.lock()
        let cont = continuation
        lock.unlock()
        cont?.yield(sampleBuffer)
    }

    func finish() {
        lock.lock()
        continuation?.finish()
        continuation = nil
        lock.unlock()
    }
}

/// Wraps AVCaptureSession with serial-queue access.
/// Call makeBufferStream() at the start of each scan to get a fresh CMSampleBuffer AsyncStream.
final class CameraSession: @unchecked Sendable {
    let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "com.celestelab.mogged.camera.session")
    private let outputQueue = DispatchQueue(label: "com.celestelab.mogged.camera.output", qos: .userInitiated)
    private let bridge = VideoOutputBridge()
    private var didConfigure = false

    enum CameraError: Error, LocalizedError {
        case noDevice
        case cannotAddInput
        case cannotAddOutput

        var errorDescription: String? {
            switch self {
            case .noDevice:        return "Front camera unavailable."
            case .cannotAddInput:  return "Couldn't attach camera input."
            case .cannotAddOutput: return "Couldn't attach video output."
            }
        }
    }

    /// Returns a fresh AsyncStream for this scan cycle.
    /// Finishes the previous stream so any blocked consumer exits cleanly.
    func makeBufferStream() -> AsyncStream<CMSampleBuffer> {
        var cont: AsyncStream<CMSampleBuffer>.Continuation!
        let stream = AsyncStream(bufferingPolicy: .bufferingNewest(2)) { cont = $0 }
        bridge.setContinuation(cont)
        return stream
    }

    func start() async throws {
        try await runOnSessionQueue { [self] in
            if !didConfigure {
                try configureOnSessionQueue()
                didConfigure = true
            }
            if !session.isRunning {
                session.startRunning()
            }
        }
    }

    func stop() async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            sessionQueue.async { [self] in
                if session.isRunning {
                    session.stopRunning()
                }
                cont.resume()
            }
        }
    }

    /// Finishes the current buffer stream so any consumer's `for await` exits cleanly.
    func finishStream() {
        bridge.finish()
    }

    // MARK: - Internal

    private func runOnSessionQueue(_ work: @escaping () throws -> Void) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            sessionQueue.async {
                do {
                    try work()
                    cont.resume()
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }

    private func configureOnSessionQueue() throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .hd1280x720

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            throw CameraError.noDevice
        }
        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else { throw CameraError.cannotAddInput }
        session.addInput(input)

        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(bridge, queue: outputQueue)
        guard session.canAddOutput(videoOutput) else { throw CameraError.cannotAddOutput }
        session.addOutput(videoOutput)

        if let connection = videoOutput.connection(with: .video) {
            if connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = true
            }
        }
    }
}
