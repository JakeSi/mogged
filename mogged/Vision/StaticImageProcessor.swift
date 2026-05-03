import Foundation
import UIKit
import MediaPipeTasksVision

final class StaticImageProcessor {
    enum ProcessorError: Error, LocalizedError {
        case modelNotFound
        case processingFailed
        case noFaceDetected

        var errorDescription: String? {
            switch self {
            case .modelNotFound: return "MediaPipe model not found."
            case .processingFailed: return "Failed to process the image."
            case .noFaceDetected: return "No face detected in the image. Please try another photo."
            }
        }
    }

    private let landmarker: FaceLandmarker

    init() throws {
        guard let modelPath = Bundle.main.path(forResource: "face_landmarker", ofType: "task") else {
            throw ProcessorError.modelNotFound
        }

        let options = FaceLandmarkerOptions()
        options.baseOptions.modelAssetPath = modelPath
        options.baseOptions.delegate = .CPU
        options.runningMode = .image
        options.numFaces = 1
        options.outputFaceBlendshapes = true
        options.outputFacialTransformationMatrixes = true
        options.minFaceDetectionConfidence = 0.5
        options.minFacePresenceConfidence = 0.5
        options.minTrackingConfidence = 0.5

        self.landmarker = try FaceLandmarker(options: options)
    }

    func process(image: UIImage, index: Int) async throws -> ScanResult {
        guard let mpImage = try? MPImage(uiImage: image) else {
            throw ProcessorError.processingFailed
        }

        let result = try landmarker.detect(image: mpImage)

        guard let face = result.faceLandmarks.first else {
            throw ProcessorError.noFaceDetected
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

        // Compute luma for the image
        let luma = computeLuma(uiImage: image)

        let frame = LandmarkFrame(
            landmarks: points,
            blendshapeSum: blendshapeSum,
            timestampMs: 0,
            imageLuma: luma
        )

        let quality = QualityGate.evaluate(frame: frame, previous: nil)
        
        // Even if quality is not "valid" (e.g. pose), we'll try to aggregate for debug
        let aggregate = try Aggregator.aggregate(frames: [frame], qualities: [quality])
        
        #if DEBUG
        print("--- DEBUG RAW METRICS (IMAGE #\(index)) ---")
        for metric in Metric.allCases where metric != .harmony {
            if let raw = aggregate.rawMetrics[metric] {
                let score = Normalizer.score(metric: metric, rawValue: raw)
                print("\(metric.rawValue): \(raw) (Score: \(String(format: "%.2f", score)))")
            }
        }
        print("-------------------------")
        #endif
        
        let thumbnail = image.cappedThumbnail(maxDimension: 400)
        
        return HarmonyEngine.makeResult(aggregate: aggregate, thumbnail: thumbnail)
    }

    private func computeLuma(uiImage: UIImage) -> Float {
        // Simplified luma calculation for static image
        // In a real app we might want to use CVPixelBuffer and MeanLuma.compute
        // but for debug this is probably fine or we can use 0.5
        return 0.5
    }
}
