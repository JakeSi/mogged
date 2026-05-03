import Foundation

enum HarmonyEngine {
    /// Combines aggregated raw metrics into final 0-10 scores + harmony + tier.
    static func finalize(aggregate: ScanAggregate) -> (perMetric: [Metric: Double], harmony: Double, tier: Tier) {
        var scored: [Metric: Double] = [:]
        for metric in Metric.allCases where metric != .harmony {
            if let raw = aggregate.rawMetrics[metric] {
                scored[metric] = Normalizer.score(metric: metric, rawValue: raw)
            }
        }

        var weightedSum = 0.0
        var totalWeight = 0.0
        for (metric, score) in scored {
            weightedSum += score * metric.weight
            totalWeight += metric.weight
        }
        let harmony = totalWeight > 0 ? min(10.0, max(0.0, weightedSum / totalWeight)) : 0.0
        let tier = Tier(harmony: harmony)
        return (scored, harmony, tier)
    }

    /// Convenience: build a ScanResult from aggregate.
    static func makeResult(aggregate: ScanAggregate, thumbnail: Data? = nil, date: Date = .now) -> ScanResult {
        let (per, harmony, tier) = finalize(aggregate: aggregate)
        return ScanResult(
            date: date,
            harmony: harmony,
            canthalTilt:    per[.canthalTilt]    ?? 0,
            jawWidth:       per[.jawWidth]        ?? 0,
            symmetry:       per[.symmetry]        ?? 0,
            midface:        per[.midface]         ?? 0,
            cheekbones:     per[.cheekbones]      ?? 0,
            eyeAspect:      per[.eyeAspect]       ?? 0,
            verticalThirds: per[.verticalThirds]  ?? 0,
            fwhr:           per[.fwhr]            ?? 0,
            jawForehead:    per[.jawForehead]      ?? 0,
            eyeSpacing:     per[.eyeSpacing]      ?? 0,
            noseLength:     per[.noseLength]       ?? 0,
            chinProjection: per[.chinProjection]   ?? 0,
            tier: tier,
            avgConfidence: aggregate.avgConfidence,
            avgReliability: aggregate.avgReliability,
            validFrames: aggregate.validFrames,
            thumbnail: thumbnail
        )
    }
}
