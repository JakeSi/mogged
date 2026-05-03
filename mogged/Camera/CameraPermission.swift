import AVFoundation

@MainActor
enum CameraPermission {
    static var status: AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .video)
    }

    static func request() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }
}
