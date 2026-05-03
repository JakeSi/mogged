import Foundation
import CoreGraphics
import simd

/// One inference result from MediaPipe Face Landmarker, plus the input frame's luma.
/// All landmark coordinates are normalized image space [0, 1].
struct LandmarkFrame: Sendable {
    /// 478 normalized 3D points, or empty if no face was detected.
    let landmarks: [SIMD3<Float>]

    /// Sum of all blendshape activations (proxy for face presence + expression coherence).
    let blendshapeSum: Float

    /// Capture timestamp in milliseconds.
    let timestampMs: Int

    /// Mean luma of the source image, [0, 1]. Used for "Too dark" detection.
    let imageLuma: Float

    static let expectedLandmarkCount = 478

    var hasFace: Bool {
        landmarks.count >= 100  // model returns ~478 when present, 0 when not — be lenient
    }

    /// Normalized face bounding box. Zero rect if no face.
    var bboxNormalized: CGRect {
        guard hasFace else { return .zero }
        var minX: Float = .infinity, maxX: Float = -.infinity
        var minY: Float = .infinity, maxY: Float = -.infinity
        for p in landmarks {
            if p.x < minX { minX = p.x }
            if p.x > maxX { maxX = p.x }
            if p.y < minY { minY = p.y }
            if p.y > maxY { maxY = p.y }
        }
        return CGRect(
            x: CGFloat(minX),
            y: CGFloat(minY),
            width: CGFloat(maxX - minX),
            height: CGFloat(maxY - minY)
        )
    }

    var faceArea: Float {
        let r = bboxNormalized
        return Float(r.width * r.height)
    }

    /// Yaw signal in roughly [-0.5, +0.5]. 0 = facing camera, +y = head turned to viewer's right.
    var yawSignal: Float {
        guard hasFace,
              let nose = at(1),
              let forehead = at(10),
              let chin = at(152),
              let leftCheek = at(234),
              let rightCheek = at(454)
        else { return 0 }
        let midX = (forehead.x + chin.x) / 2
        let halfWidth = max(0.001, abs(rightCheek.x - leftCheek.x) / 2)
        return (nose.x - midX) / halfWidth
    }

    /// Pitch signal in roughly [-0.5, +0.5]. 0 = neutral, +y = head tilted down.
    var pitchSignal: Float {
        guard hasFace,
              let nose = at(1),
              let forehead = at(10),
              let chin = at(152)
        else { return 0 }
        let midY = (forehead.y + chin.y) / 2
        let halfHeight = max(0.001, abs(chin.y - forehead.y) / 2)
        return (nose.y - midY) / halfHeight
    }

    /// Standard deviation of landmark Z coordinates. Degenerate flat z → low confidence.
    var zVariance: Float {
        guard hasFace else { return 0 }
        let zs = landmarks.map { $0.z }
        let mean = zs.reduce(0, +) / Float(zs.count)
        let sq = zs.reduce(0) { $0 + ($1 - mean) * ($1 - mean) }
        return (sq / Float(zs.count)).squareRoot()
    }

    /// Safe landmark accessor.
    func at(_ index: Int) -> SIMD3<Float>? {
        guard index >= 0, index < landmarks.count else { return nil }
        return landmarks[index]
    }

    static func empty(timestampMs: Int, luma: Float) -> LandmarkFrame {
        LandmarkFrame(landmarks: [], blendshapeSum: 0, timestampMs: timestampMs, imageLuma: luma)
    }
}
