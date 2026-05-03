import SwiftUI
import AVFoundation
import simd

/// Curated subset of MediaPipe FaceMesh indices that "read" as a face outline
/// without looking like a chaotic point cloud. ~40 points.
struct LandmarkOverlay: View {
    let landmarks: [SIMD3<Float>]

    /// Actual dimensions of the buffer MediaPipe is processing (post-rotation, post-mirroring).
    /// Used only by the manual aspect-fill fallback when the preview layer isn't available yet.
    let videoSize: CGSize?

    /// When available, the overlay defers all coordinate conversion to the preview layer's own
    /// `layerPointConverted(fromCaptureDevicePoint:)`, so aspect-fill, rotation, and mirroring
    /// match the rendered video exactly. This is more robust than reproducing the math because
    /// `AVCaptureVideoPreviewLayer` is the authority on its own gravity.
    let previewLayer: AVCaptureVideoPreviewLayer?

    var liveQuality: FrameQuality? = nil
    var collectedFrames: Int = 0

    private static let fallbackVideoSize = CGSize(width: 720, height: 1280)

    /// The key measurement landmarks — drawn as large dots.
    /// Forehead, brow centers, eye corners, nose tip + nostrils, mouth corners + center, jaw corners, chin.
    static let keyPoints: [Int] = [
        10,                  // forehead
        105, 334,            // brow centers
        33, 133, 362, 263,   // eye corners (outer + inner, both eyes)
        1, 49, 279,          // nose tip + nostrils
        78, 308, 13, 14,     // mouth corners + upper/lower centers
        234, 454,            // jaw corners
        152                  // chin
    ]

    /// Secondary landmarks — drawn as small dots for facial outline context.
    static let highlighted: [Int] = [
        // face oval
        10, 338, 297, 332, 284, 251, 389, 356, 454, 323, 361, 288, 397, 365, 379, 378, 400, 377, 152,
        148, 176, 149, 150, 136, 172, 58, 132, 93, 234, 127, 162, 21, 54, 103, 67, 109,
        // eyes (corners + caps)
        33, 133, 159, 145,
        362, 263, 386, 374,
        // nose
        1, 2, 6, 168,
        // lips
        13, 14, 78, 308,
        // brows (sparse)
        70, 105, 300, 334
    ]

    private static let dotColor = Color(red: 0.18, green: 1.0, blue: 0.35)

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Canvas { ctx, size in
                guard landmarks.count >= LandmarkFrame.expectedLandmarkCount else { return }
                let keySet = Set(Self.keyPoints)
                let smallColor = GraphicsContext.Shading.color(Self.dotColor.opacity(0.85))
                let largeColor = GraphicsContext.Shading.color(Self.dotColor)
                let project = projection(in: size)

                // Small dots for context
                for index in Self.highlighted where !keySet.contains(index) {
                    guard index < landmarks.count else { continue }
                    let pt = project(landmarks[index])
                    let r: CGFloat = 1
                    let dot = CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2)
                    ctx.fill(Path(ellipseIn: dot), with: smallColor)
                }

                // Large dots for key measurement points
                for index in Self.keyPoints {
                    guard index < landmarks.count else { continue }
                    let pt = project(landmarks[index])
                    let r: CGFloat = 2
                    let dot = CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2)
                    ctx.fill(Path(ellipseIn: dot), with: largeColor)
                }
            }
            .allowsHitTesting(false)

            debugHUD
                .padding(.bottom, 60)
                .padding(.leading, 12)
                .allowsHitTesting(false)
        }
    }

    /// Temporary on-screen diagnostics. Remove once alignment and scoring are dialed in.
    private var debugHUD: some View {
        let nose = landmarks.indices.contains(1) ? landmarks[1] : SIMD3<Float>(repeating: 0)
        let video = videoSize ?? Self.fallbackVideoSize
        let conf = liveQuality.map { String(format: "%.2f", $0.confidence) } ?? "—"
        let rel  = liveQuality.map { String(format: "%.2f", $0.reliability) } ?? "—"
        return VStack(alignment: .leading, spacing: 2) {
            Text("video \(Int(video.width))×\(Int(video.height))")
            Text(String(format: "nose %.3f, %.3f", nose.x, nose.y))
            Text("confidence \(conf)")
            Text("reliability \(rel)")
            Text("frames \(collectedFrames)")
        }
        .font(.system(size: 10, weight: .medium, design: .monospaced))
        .foregroundStyle(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 4))
    }

    private func projection(in canvasSize: CGSize) -> (SIMD3<Float>) -> CGPoint {
        if let layer = previewLayer {
            return { landmark in
                // MediaPipe coordinates are normalized inside the buffer that
                // `AVCaptureVideoDataOutput` delivered — already rotated 90° and horizontally
                // mirrored by the connection. `layerPointConverted(fromCaptureDevicePoint:)`
                // expects the *capture device's* native sensor space (landscape, unmirrored),
                // so we invert that pair of transforms.
                //
                // Forward (sensor → buffer) for a 90° rotation + horizontal mirror:
                //     buffer.x = sensor.y
                //     buffer.y = sensor.x
                // Inverse:
                //     sensor.x = buffer.y
                //     sensor.y = buffer.x
                //
                // If the connection is rotating the other direction on a given device, this
                // pair flips to (1 − buffer.y, 1 − buffer.x); we'll know if landmarks land
                // on the mirrored half of the face.
                let sensorPoint = CGPoint(x: CGFloat(landmark.y), y: CGFloat(landmark.x))
                return layer.layerPointConverted(fromCaptureDevicePoint: sensorPoint)
            }
        }
        return manualAspectFillProjection(in: canvasSize)
    }

    /// Fallback used until the preview layer is wired up. Reproduces `AVCaptureVideoPreviewLayer`'s
    /// `.resizeAspectFill` math against the known buffer size: scale image to cover the canvas,
    /// centered, with overflow cropped on whichever axis is longer.
    private func manualAspectFillProjection(in size: CGSize) -> (SIMD3<Float>) -> CGPoint {
        let video = videoSize ?? Self.fallbackVideoSize
        let imageAspect = video.width / video.height
        let viewAspect = size.width / size.height

        let displayed: CGSize
        if imageAspect > viewAspect {
            displayed = CGSize(width: size.height * imageAspect, height: size.height)
        } else {
            displayed = CGSize(width: size.width, height: size.width / imageAspect)
        }

        let xOffset = (size.width - displayed.width) / 2
        let yOffset = (size.height - displayed.height) / 2

        return { landmark in
            CGPoint(
                x: xOffset + CGFloat(landmark.x) * displayed.width,
                y: yOffset + CGFloat(landmark.y) * displayed.height
            )
        }
    }
}
