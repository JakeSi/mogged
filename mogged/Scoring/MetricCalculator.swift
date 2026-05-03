import Foundation
import simd

/// Pure computation of raw metric values from a LandmarkFrame.
/// All metrics return nil if required landmarks are missing.
/// Symmetry returns a direct 0-10 score; everything else returns the raw measurement
/// (degrees or ratio) for the Normalizer to map onto a 0-10 scale.
enum MetricCalculator {

    /// Canonical MediaPipe Face Mesh indices used by the metric formulas.
    enum Idx {
        static let leftEyeOuter = 33,  leftEyeInner = 133
        static let leftEyeTop   = 159, leftEyeBottom = 145
        static let rightEyeInner = 362, rightEyeOuter = 263
        static let rightEyeTop   = 386, rightEyeBottom = 374
        static let foreheadTop = 10, glabella = 9
        static let noseTip = 1,  subnasale = 2
        static let chinBottom = 152
        static let upperLip = 13, lowerLip = 14
        static let leftJaw = 172, rightJaw = 397
        static let leftCheek = 234, rightCheek = 454
        static let leftMouthCorner = 61, rightMouthCorner = 291
        static let leftBrow = 105, rightBrow = 334
        // Proportion metrics
        static let leftBrowArch = 70,  rightBrowArch = 300
        static let nasion = 168
        static let leftTemple = 127,   rightTemple = 356
    }

    /// Bilateral ratio floor: avg ratio at or below this maps to score 0.
    /// Ratios compare left vs right measurements; 1.0 = perfect symmetry.
    static let symmetryFloorRatio: Double = 0.70

    // MARK: - Metrics

    static func canthalTiltDegrees(_ f: LandmarkFrame) -> Double? {
        guard let lo = f.at(Idx.leftEyeOuter),  let li = f.at(Idx.leftEyeInner),
              let ri = f.at(Idx.rightEyeInner), let ro = f.at(Idx.rightEyeOuter)
        else { return nil }
        // Convention: positive = outer canthus higher than inner ("hunter eyes").
        // Image y grows downward, so inner.y - outer.y > 0 when outer is higher.
        let leftTilt = atan2(Double(li.y - lo.y),  Double(abs(lo.x - li.x)))
        let rightTilt = atan2(Double(ri.y - ro.y), Double(abs(ro.x - ri.x)))
        let avg = (leftTilt + rightTilt) / 2.0
        return avg * (180.0 / .pi)
    }

    static func jawRatio(_ f: LandmarkFrame) -> Double? {
        guard let l = f.at(Idx.leftJaw), let r = f.at(Idx.rightJaw),
              let top = f.at(Idx.foreheadTop), let bot = f.at(Idx.chinBottom)
        else { return nil }
        let jaw = dist2D(l, r)
        let face = dist2D(top, bot)
        guard face > 0 else { return nil }
        return jaw / face
    }

    static func symmetryScore(_ f: LandmarkFrame) -> Double? {
        var ratios: [Double] = []

        // Eye vertical opening (Y only — yaw-invariant)
        if let lt = f.at(Idx.leftEyeTop),  let lb = f.at(Idx.leftEyeBottom),
           let rt = f.at(Idx.rightEyeTop), let rb = f.at(Idx.rightEyeBottom),
           let r = bilateralRatio(Double(abs(lt.y - lb.y)), Double(abs(rt.y - rb.y))) {
            ratios.append(r)
        }

        // Brow-to-eye vertical distance (Y only — yaw-invariant)
        if let lbrow = f.at(Idx.leftBrow),  let le = f.at(Idx.leftEyeTop),
           let rbrow = f.at(Idx.rightBrow), let re = f.at(Idx.rightEyeTop),
           let r = bilateralRatio(Double(abs(lbrow.y - le.y)), Double(abs(rbrow.y - re.y))) {
            ratios.append(r)
        }

        // Eyebrow-to-nose Y distance (catches one brow sitting higher than the other)
        if let nose  = f.at(Idx.noseTip),
           let lbrow = f.at(Idx.leftBrow), let rbrow = f.at(Idx.rightBrow),
           let r = bilateralRatio(Double(abs(lbrow.y - nose.y)), Double(abs(rbrow.y - nose.y))) {
            ratios.append(r)
        }

        // Cheek-to-nose Y distance (yaw-invariant)
        if let nose = f.at(Idx.noseTip),
           let lc = f.at(Idx.leftCheek), let rc = f.at(Idx.rightCheek),
           let r = bilateralRatio(Double(abs(lc.y - nose.y)), Double(abs(rc.y - nose.y))) {
            ratios.append(r)
        }

        // Cheek-to-nose 2D distance (captures lateral cheek width asymmetry)
        if let nose = f.at(Idx.noseTip),
           let lc = f.at(Idx.leftCheek), let rc = f.at(Idx.rightCheek),
           let r = bilateralRatio(dist2D(lc, nose), dist2D(rc, nose)) {
            ratios.append(r)
        }

        // Mouth corner-to-nose Y distance (yaw-invariant)
        if let nose = f.at(Idx.noseTip),
           let lm = f.at(Idx.leftMouthCorner), let rm = f.at(Idx.rightMouthCorner),
           let r = bilateralRatio(Double(abs(lm.y - nose.y)), Double(abs(rm.y - nose.y))) {
            ratios.append(r)
        }

        // Mouth corner-to-nose 2D distance (captures lateral mouth asymmetry)
        if let nose = f.at(Idx.noseTip),
           let lm = f.at(Idx.leftMouthCorner), let rm = f.at(Idx.rightMouthCorner),
           let r = bilateralRatio(dist2D(lm, nose), dist2D(rm, nose)) {
            ratios.append(r)
        }

        // Jaw-to-nose Y distance (yaw-invariant)
        if let nose = f.at(Idx.noseTip),
           let lj = f.at(Idx.leftJaw), let rj = f.at(Idx.rightJaw),
           let r = bilateralRatio(Double(abs(lj.y - nose.y)), Double(abs(rj.y - nose.y))) {
            ratios.append(r)
        }

        // Jaw-to-nose 2D distance (captures jaw width asymmetry)
        if let nose = f.at(Idx.noseTip),
           let lj = f.at(Idx.leftJaw), let rj = f.at(Idx.rightJaw),
           let r = bilateralRatio(dist2D(lj, nose), dist2D(rj, nose)) {
            ratios.append(r)
        }

        guard !ratios.isEmpty else { return nil }

        let avg = ratios.reduce(0, +) / Double(ratios.count)
        let rawScore = (avg - symmetryFloorRatio) / (1.0 - symmetryFloorRatio) * 10.0
        let score = min(10.0, max(0.0, rawScore))
        return score
    }

    static func midfaceRatio(_ f: LandmarkFrame) -> Double? {
        guard let li = f.at(Idx.leftEyeInner), let ri = f.at(Idx.rightEyeInner),
              let ul = f.at(Idx.upperLip), let ll = f.at(Idx.lowerLip),
              let top = f.at(Idx.foreheadTop), let bot = f.at(Idx.chinBottom)
        else { return nil }

        let eyeCenter = SIMD3<Float>((li.x + ri.x) / 2, (li.y + ri.y) / 2, 0)
        let lipCenter = SIMD3<Float>((ul.x + ll.x) / 2, (ul.y + ll.y) / 2, 0)
        let mid = dist2D(eyeCenter, lipCenter)
        let face = dist2D(top, bot)
        guard face > 0 else { return nil }
        return mid / face
    }

    static func cheekboneRatio(_ f: LandmarkFrame) -> Double? {
        guard let lc = f.at(Idx.leftCheek), let rc = f.at(Idx.rightCheek),
              let lj = f.at(Idx.leftJaw), let rj = f.at(Idx.rightJaw)
        else { return nil }
        let cheek = dist2D(lc, rc)
        let jaw = dist2D(lj, rj)
        guard jaw > 0 else { return nil }
        return cheek / jaw
    }

    static func eyeAspectRatio(_ f: LandmarkFrame) -> Double? {
        guard let lt = f.at(Idx.leftEyeTop),  let lb = f.at(Idx.leftEyeBottom),
              let lo = f.at(Idx.leftEyeOuter), let li = f.at(Idx.leftEyeInner),
              let rt = f.at(Idx.rightEyeTop), let rb = f.at(Idx.rightEyeBottom),
              let ri = f.at(Idx.rightEyeInner), let ro = f.at(Idx.rightEyeOuter)
        else { return nil }
        let leftV  = dist2D(lt, lb), leftH  = dist2D(lo, li)
        let rightV = dist2D(rt, rb), rightH = dist2D(ri, ro)
        guard leftH > 0, rightH > 0 else { return nil }
        return ((leftV / leftH) + (rightV / rightH)) / 2.0
    }

    // MARK: - Proportion Metrics

    /// Returns a 0-10 score: 10 = perfect equal thirds, lower = imbalanced thirds.
    static func verticalThirdsScore(_ f: LandmarkFrame) -> Double? {
        guard let hairline  = f.at(Idx.foreheadTop),
              let lba       = f.at(Idx.leftBrowArch),
              let rba       = f.at(Idx.rightBrowArch),
              let noseBase  = f.at(Idx.subnasale),
              let chin      = f.at(Idx.chinBottom)
        else { return nil }

        let browY     = Double((lba.y + rba.y) / 2)
        let hairlineY = Double(hairline.y)
        let noseY     = Double(noseBase.y)
        let chinY     = Double(chin.y)

        let faceHeight = abs(chinY - hairlineY)
        guard faceHeight > 1e-6 else { return nil }

        let t1 = abs(browY - hairlineY) / faceHeight
        let t2 = abs(noseY - browY)     / faceHeight
        let t3 = abs(chinY - noseY)     / faceHeight

        let mean   = (t1 + t2 + t3) / 3.0
        guard mean > 1e-6 else { return nil }
        let variance = ((t1-mean)*(t1-mean) + (t2-mean)*(t2-mean) + (t3-mean)*(t3-mean)) / 3.0
        let stddev   = variance.squareRoot()

        let score = max(0, 1.0 - stddev / mean)
        return score * 10.0
    }

    /// Facial Width-to-Height Ratio: cheek width / (forehead-top to upper-lip height).
    static func fwhrRatio(_ f: LandmarkFrame) -> Double? {
        guard let lc  = f.at(Idx.leftCheek),  let rc = f.at(Idx.rightCheek),
              let top = f.at(Idx.foreheadTop), let ul = f.at(Idx.upperLip)
        else { return nil }
        let width  = dist2D(lc, rc)
        let height = dist2D(top, ul)
        guard height > 1e-6 else { return nil }
        return width / height
    }

    /// Jaw width vs forehead/temple width.
    static func jawForeheadRatio(_ f: LandmarkFrame) -> Double? {
        guard let lj = f.at(Idx.leftJaw),    let rj = f.at(Idx.rightJaw),
              let lt = f.at(Idx.leftTemple), let rt = f.at(Idx.rightTemple)
        else { return nil }
        let jaw      = dist2D(lj, rj)
        let forehead = dist2D(lt, rt)
        guard forehead > 1e-6 else { return nil }
        return jaw / forehead
    }

    /// Eye spacing / average eye width (inner-corner span divided by eye width).
    static func eyeSpacingRatio(_ f: LandmarkFrame) -> Double? {
        guard let lio = f.at(Idx.leftEyeOuter),  let lii = f.at(Idx.leftEyeInner),
              let rio = f.at(Idx.rightEyeOuter), let rii = f.at(Idx.rightEyeInner)
        else { return nil }
        let leftW   = dist2D(lio, lii)
        let rightW  = dist2D(rio, rii)
        let eyeW    = (leftW + rightW) / 2.0
        let spacing = dist2D(lii, rii)
        guard eyeW > 1e-6 else { return nil }
        return spacing / eyeW
    }

    /// Nose bridge to tip length as proportion of total face height.
    static func noseLengthRatio(_ f: LandmarkFrame) -> Double? {
        guard let nasion  = f.at(Idx.nasion),
              let noseTip = f.at(Idx.subnasale),
              let top     = f.at(Idx.foreheadTop),
              let chin    = f.at(Idx.chinBottom)
        else { return nil }
        let noseLen   = dist2D(nasion, noseTip)
        let faceHeight = dist2D(top, chin)
        guard faceHeight > 1e-6 else { return nil }
        return noseLen / faceHeight
    }

    /// Chin-to-lip / lip-to-nose ratio as a frontal chin projection proxy.
    static func chinProjectionRatio(_ f: LandmarkFrame) -> Double? {
        guard let chin    = f.at(Idx.chinBottom),
              let lowerLip = f.at(Idx.lowerLip),
              let noseTip  = f.at(Idx.noseTip)
        else { return nil }
        let chinToLip = dist2D(chin, lowerLip)
        let lipToNose = dist2D(lowerLip, noseTip)
        guard lipToNose > 1e-6 else { return nil }
        return chinToLip / lipToNose
    }

    // MARK: - Helpers

    private static func dist2D(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Double {
        let dx = Double(b.x - a.x)
        let dy = Double(b.y - a.y)
        return (dx * dx + dy * dy).squareRoot()
    }

    /// min/max ratio of two bilateral measurements. Returns nil if both are ~0.
    private static func bilateralRatio(_ a: Double, _ b: Double) -> Double? {
        guard max(a, b) > 1e-6 else { return nil }
        return min(a, b) / max(a, b)
    }
}
