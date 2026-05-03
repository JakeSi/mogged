import Foundation

enum Tier: String, CaseIterable, Sendable {
    case subhuman
    case lowTierNormie
    case midTierNormie
    case highTierNormie
    case chadlite
    case chad
    case adamlite
    case trueAdam

    var displayName: String {
        switch self {
        case .subhuman:       return "Subhuman"
        case .lowTierNormie:  return "Low Tier Normie"
        case .midTierNormie:  return "Mid Tier Normie"
        case .highTierNormie: return "High Tier Normie"
        case .chadlite:       return "Chadlite"
        case .chad:           return "Chad"
        case .adamlite:       return "Adamlite"
        case .trueAdam:       return "True Adam"
        }
    }

    init(harmony: Double) {
        let h = max(0.0, min(10.0, harmony))
        switch h {
        case ..<5.5:    self = .subhuman
        case ..<6.5:    self = .lowTierNormie
        case ..<7.0:    self = .midTierNormie
        case ..<7.5:    self = .highTierNormie
        case ..<8.5:    self = .chadlite
        case ..<9.5:    self = .chad
        default:        self = .trueAdam
        }
    }
}
