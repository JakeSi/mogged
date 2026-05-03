import Foundation
import SwiftData

@Model
final class ScanResult {
    var date: Date
    var harmony: Double

    var canthalTilt: Double
    var jawWidth: Double
    var symmetry: Double
    var midface: Double
    var cheekbones: Double
    var eyeAspect: Double
    var verticalThirds: Double
    var fwhr: Double
    var jawForehead: Double
    var eyeSpacing: Double
    var noseLength: Double
    var chinProjection: Double

    var tierRaw: String
    var avgConfidence: Double
    var avgReliability: Double
    var validFrames: Int
    var thumbnail: Data?

    init(
        date: Date = .now,
        harmony: Double,
        canthalTilt: Double,
        jawWidth: Double,
        symmetry: Double,
        midface: Double,
        cheekbones: Double,
        eyeAspect: Double,
        verticalThirds: Double,
        fwhr: Double,
        jawForehead: Double,
        eyeSpacing: Double,
        noseLength: Double,
        chinProjection: Double,
        tier: Tier,
        avgConfidence: Double,
        avgReliability: Double,
        validFrames: Int,
        thumbnail: Data? = nil
    ) {
        self.date = date
        self.harmony = harmony
        self.canthalTilt = canthalTilt
        self.jawWidth = jawWidth
        self.symmetry = symmetry
        self.midface = midface
        self.cheekbones = cheekbones
        self.eyeAspect = eyeAspect
        self.verticalThirds = verticalThirds
        self.fwhr = fwhr
        self.jawForehead = jawForehead
        self.eyeSpacing = eyeSpacing
        self.noseLength = noseLength
        self.chinProjection = chinProjection
        self.tierRaw = tier.rawValue
        self.avgConfidence = avgConfidence
        self.avgReliability = avgReliability
        self.validFrames = validFrames
        self.thumbnail = thumbnail
    }

    var tier: Tier {
        Tier(rawValue: tierRaw) ?? Tier(harmony: harmony)
    }

    func score(for metric: Metric) -> Double {
        switch metric {
        case .canthalTilt:    return canthalTilt
        case .jawWidth:       return jawWidth
        case .symmetry:       return symmetry
        case .midface:        return midface
        case .cheekbones:     return cheekbones
        case .eyeAspect:      return eyeAspect
        case .verticalThirds: return verticalThirds
        case .fwhr:           return fwhr
        case .jawForehead:    return jawForehead
        case .eyeSpacing:     return eyeSpacing
        case .noseLength:     return noseLength
        case .chinProjection: return chinProjection
        case .harmony:        return harmony
        }
    }
}
