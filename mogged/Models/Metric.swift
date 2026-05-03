import Foundation

enum Metric: String, CaseIterable, Sendable, Identifiable {
    case canthalTilt
    case jawWidth
    case symmetry
    case midface
    case cheekbones
    case eyeAspect
    case verticalThirds
    case fwhr
    case jawForehead
    case eyeSpacing
    case noseLength
    case chinProjection
    case harmony

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .canthalTilt:    return "Canthal Tilt"
        case .jawWidth:       return "Jaw Width"
        case .symmetry:       return "Symmetry"
        case .midface:        return "Midface"
        case .cheekbones:     return "Cheekbones"
        case .eyeAspect:      return "Eye Aspect"
        case .verticalThirds: return "Facial Thirds"
        case .fwhr:           return "Facial Aspect Index"
        case .jawForehead:    return "Facial Width Distribution"
        case .eyeSpacing:     return "Eye Spacing"
        case .noseLength:     return "Nasal Projection"
        case .chinProjection: return "Chin"
        case .harmony:        return "Harmony"
        }
    }

    var tagline: String {
        switch self {
        case .canthalTilt:    return "A slight upward tilt from inner to outer corner adds sharpness and intensity to your gaze."
        case .jawWidth:       return "A well-proportioned jaw relative to your face height adds structure and definition."
        case .symmetry:       return "How evenly balanced the two halves of your face are — one of the most reliable markers of attractiveness."
        case .midface:        return "A compact distance between your eyes and mouth tends to read as more youthful and balanced."
        case .cheekbones:     return "Cheekbones that flare wider than the jaw create the sharp, angular look associated with high attractiveness."
        case .eyeAspect:      return "Almond-shaped eyes with a moderate height-to-width ratio are considered the most attractive eye shape."
        case .verticalThirds: return "Balanced upper, mid, and lower thirds of the face are a classical marker of ideal facial proportions."
        case .fwhr:           return "The ratio of face width to height determines whether your face reads as compact and striking or elongated."
        case .jawForehead:    return "A jaw that echoes the width of the forehead creates a structurally balanced, angular silhouette."
        case .eyeSpacing:     return "Eyes spaced exactly one eye-width apart produce the most balanced and harmonious gaze."
        case .noseLength:     return "A nose that occupies the ideal proportion of total face height keeps the midface from looking dominant or recessed."
        case .chinProjection: return "A chin that projects slightly beyond the lower lip adds definition and prevents a soft, receded lower face."
        case .harmony:        return "Weighted composite of all metrics. The overall verdict."
        }
    }

    /// Display index ("01" ... "13") matching card labels.
    var indexLabel: String {
        guard let i = Self.allCases.firstIndex(of: self) else { return "00" }
        return String(format: "%02d", i + 1)
    }

    /// Weight applied in the harmony composite.
    var weight: Double {
        switch self {
        case .eyeAspect:      return 1.6
        case .jawWidth:       return 1.5
        case .midface:        return 1.4
        case .fwhr:           return 1.4
        case .canthalTilt:    return 1.0
        case .jawForehead:    return 1.0
        case .verticalThirds: return 1.0
        case .symmetry:       return 0.8
        case .eyeSpacing:     return 0.7
        case .noseLength:     return 0.5
        case .chinProjection: return 0.5
        case .harmony:        return 0
        default:              return 1.0
        }
    }
}
