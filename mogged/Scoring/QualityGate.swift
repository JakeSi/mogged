import Foundation
import simd

enum FaultSeverity: Sendable {
    case warning
    case invalid
}

enum Fault: String, Sendable, CaseIterable, Identifiable {
    case noFace
    case tooDark
    case moveCloser
    case moveBack
    case turnLeft
    case turnRight
    case tiltUp
    case tiltDown
    case holdStill

    var id: String { rawValue }

    var label: String {
        switch self {
        case .noFace:     return Copy.Faults.noFace
        case .tooDark:    return Copy.Faults.tooDark
        case .moveCloser: return Copy.Faults.moveCloser
        case .moveBack:   return Copy.Faults.moveBack
        case .turnLeft:   return Copy.Faults.turnLeft
        case .turnRight:  return Copy.Faults.turnRight
        case .tiltUp:     return Copy.Faults.tiltUp
        case .tiltDown:   return Copy.Faults.tiltDown
        case .holdStill:  return Copy.Faults.holdStill
        }
    }

    var severity: FaultSeverity {
        switch self {
        case .noFace, .tooDark: return .invalid
        default:                return .warning
        }
    }
}

struct FrameQuality: Sendable {
    /// 0...1 — derived from blendshape activation + landmark z-variance.
    let confidence: Double
    /// 0...1 — face area + pose moderation + inter-frame stability.
    let reliability: Double
    /// User-facing faults, in priority order.
    let faults: [Fault]

    var isValid: Bool {
        guard faults.allSatisfy({ $0.severity != .invalid }) else { return false }
        return confidence > 0.7
    }
}

enum QualityGate {

    static func evaluate(frame: LandmarkFrame, previous: LandmarkFrame?) -> FrameQuality {
        guard frame.hasFace else {
            return FrameQuality(confidence: 0, reliability: 0, faults: [.noFace])
        }

        var faults: [Fault] = []

        if frame.imageLuma < 0.25 { faults.append(.tooDark) }

        let area = Double(frame.faceArea)
        if area < 0.10 { faults.append(.moveCloser) }
        if area > 0.60 { faults.append(.moveBack) }

        let yaw = Double(frame.yawSignal)
        if yaw > 0.18 { faults.append(.turnRight) }
        else if yaw < -0.18 { faults.append(.turnLeft) }

        let pitch = Double(frame.pitchSignal)
        if pitch > 0.20 { faults.append(.tiltDown) }
        else if pitch < -0.20 { faults.append(.tiltUp) }

        // Reliability: bbox in target zone × pose moderate × stability vs prev frame.
        let areaScore = clamp01((min(area, 0.50) - 0.05) / 0.30)
        let yawScore = max(0, 1 - abs(yaw) / 0.30)
        let pitchScore = max(0, 1 - abs(pitch) / 0.30)

        var stabilityScore = 1.0
        if let prev = previous, prev.hasFace,
           let nowNose = frame.at(MetricCalculator.Idx.noseTip),
           let prevNose = prev.at(MetricCalculator.Idx.noseTip) {
            let jitter = Double(simdDistance(nowNose, prevNose))
            stabilityScore = max(0, 1 - jitter / 0.05)
        }
        let reliability = areaScore * yawScore * pitchScore * stabilityScore

        // Confidence: blendshape activation + z variance non-degenerate.
        let blendshapeScore = clamp01(Double(frame.blendshapeSum) / 1.5)
        let zVarScore = clamp01(Double(frame.zVariance) / 0.025)
        let confidence = max(0.0, (blendshapeScore + zVarScore) / 2.0)

        if confidence < 0.55 { faults.append(.holdStill) }

        return FrameQuality(confidence: confidence, reliability: reliability, faults: faults)
    }

    private static func clamp01(_ v: Double) -> Double { min(max(v, 0), 1) }

    private static func simdDistance(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float {
        let dx = b.x - a.x, dy = b.y - a.y
        return (dx * dx + dy * dy).squareRoot()
    }
}
