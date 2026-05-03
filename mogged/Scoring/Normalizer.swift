import Foundation

struct MetricBand: Sendable {
    let idealLow: Double
    let idealHigh: Double
    /// One-sided sigma — distance below ideal_low (or above ideal_high) at which score drops by 2.
    let sigma: Double
}

enum Normalizer {
    /// Per-metric ideal bands.
    /// Metrics that return a direct 0-10 score (symmetry, verticalThirds) are omitted.
    static let bands: [Metric: MetricBand] = [
        .canthalTilt:    MetricBand(idealLow: 3,  idealHigh: 5.5,  sigma: 0.5),
        .jawWidth:       MetricBand(idealLow: 0.82, idealHigh: 1.1, sigma: 0.06),
        .midface:        MetricBand(idealLow: 0.40, idealHigh: 0.42, sigma: 0.03),
        .cheekbones:     MetricBand(idealLow: 1.25, idealHigh: 1.42, sigma: 0.04),
        .eyeAspect:      MetricBand(idealLow: 0.24, idealHigh: 0.28, sigma: 0.02),
        .fwhr:           MetricBand(idealLow: 1.55, idealHigh: 1.70, sigma: 0.15),
        .jawForehead:    MetricBand(idealLow: 0.85, idealHigh: 1.05, sigma: 0.10),
        .eyeSpacing:     MetricBand(idealLow: 1.25, idealHigh: 1.35, sigma: 0.10),
        .noseLength:     MetricBand(idealLow: 0.31, idealHigh: 0.32, sigma: 0.03),
        .chinProjection: MetricBand(idealLow: 1.25, idealHigh: 1.40, sigma: 0.12),
    ]
    
    /// Maps a raw measurement to a 0-10 score.
    /// Symmetry and verticalThirds return a direct 0-10 score and pass through unchanged.
    static func score(metric: Metric, rawValue: Double) -> Double {
        if metric == .symmetry || metric == .verticalThirds { return clamp(rawValue, 0, 10) }
        guard let band = bands[metric] else { return clamp(rawValue, 0, 10) }
        return scoreInBand(rawValue, band: band)
    }
    
    /// Piecewise: inside band → 9-10 (slight inner gradient).
    /// Within 1σ outside → 7-9 ramp. Within 2σ → 5-7. Beyond → floor 3.
    static func scoreInBand(_ x: Double, band: MetricBand) -> Double {
        let lo = band.idealLow
        let hi = band.idealHigh
        let sigma = max(0.0001, band.sigma)
        
        if x >= lo && x <= hi {
            let mid = (lo + hi) / 2
            let halfRange = max(0.0001, (hi - lo) / 2)
            let centerDist = min(1, abs(x - mid) / halfRange)
            return 10.0 - centerDist * 1.0  // 10 at center, 9 at band edges
        }
        
        let distanceOutside = (x < lo) ? (lo - x) : (x - hi)
        let sigmas = distanceOutside / sigma
        switch sigmas {
        case ..<1.0:
            return 9.0 - sigmas * 2.0      // 9 at band edge → 7 at 1σ
        case ..<2.0:
            return 7.0 - (sigmas - 1) * 2.0 // 7 at 1σ → 5 at 2σ
        default:
            return max(0.0, 5.0 - (sigmas - 2.0) * 2.5)  // Steeper drop-off and 0 floor
        }
    }
    
    private static func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double {
        min(max(v, lo), hi)
    }
}
