import Foundation

struct ScanAggregate: Sendable {
    /// Raw measurement per metric (degrees or ratio for normalized metrics; 0-10 for symmetry).
    let rawMetrics: [Metric: Double]
    let avgConfidence: Double
    let avgReliability: Double
    let validFrames: Int
}

enum AggregationFailure: Error, LocalizedError {
    case insufficientFrames(have: Int, need: Int)

    var errorDescription: String? {
        switch self {
        case .insufficientFrames(let have, let need):
            return "Only \(have)/\(need) frames passed."
        }
    }
}

enum Aggregator {
    static let trimFraction: Double = 0.18
    static let minValidFrames = 1

    static func aggregate(frames: [LandmarkFrame], qualities: [FrameQuality]) throws -> ScanAggregate {
        precondition(frames.count == qualities.count, "frames and qualities must align")
        let pairs = zip(frames, qualities).filter { $0.1.isValid }

        guard pairs.count >= minValidFrames else {
            throw AggregationFailure.insufficientFrames(have: pairs.count, need: minValidFrames)
        }

        let avgConf = pairs.map(\.1.confidence).reduce(0, +) / Double(pairs.count)
        let avgRel  = pairs.map(\.1.reliability).reduce(0, +) / Double(pairs.count)

        let validFrames = pairs.map(\.0)
        var raw: [Metric: Double] = [:]
        for metric in Metric.allCases where metric != .harmony {
            let series = validFrames.compactMap { rawValue(of: metric, in: $0) }
            if let trimmed = trimmedMean(series, fraction: trimFraction) {
                raw[metric] = trimmed
            }
        }

        return ScanAggregate(
            rawMetrics: raw,
            avgConfidence: avgConf,
            avgReliability: avgRel,
            validFrames: validFrames.count
        )
    }

    static func rawValue(of metric: Metric, in frame: LandmarkFrame) -> Double? {
        switch metric {
        case .canthalTilt:    return MetricCalculator.canthalTiltDegrees(frame)
        case .jawWidth:       return MetricCalculator.jawRatio(frame)
        case .symmetry:       return MetricCalculator.symmetryScore(frame)
        case .midface:        return MetricCalculator.midfaceRatio(frame)
        case .cheekbones:     return MetricCalculator.cheekboneRatio(frame)
        case .eyeAspect:      return MetricCalculator.eyeAspectRatio(frame)
        case .verticalThirds: return MetricCalculator.verticalThirdsScore(frame)
        case .fwhr:           return MetricCalculator.fwhrRatio(frame)
        case .jawForehead:    return MetricCalculator.jawForeheadRatio(frame)
        case .eyeSpacing:     return MetricCalculator.eyeSpacingRatio(frame)
        case .noseLength:     return MetricCalculator.noseLengthRatio(frame)
        case .chinProjection: return MetricCalculator.chinProjectionRatio(frame)
        case .harmony:        return nil
        }
    }

    static func trimmedMean(_ values: [Double], fraction: Double) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let n = sorted.count
        let trim = Int(Double(n) * fraction)
        let lo = trim
        let hi = n - trim
        guard lo < hi else { return sorted[n / 2] }
        let slice = sorted[lo..<hi]
        return slice.reduce(0, +) / Double(slice.count)
    }
}
