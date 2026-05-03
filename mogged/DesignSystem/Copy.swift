import Foundation

/// Centralized user-facing strings. Voice: confident, technical, slightly cocky.
enum Copy {
    enum Home {
        static let title = "mogged"
        static let subhead = "Seven metrics. One verdict."
        static let body = "MediaPipe Face Mesh tracks 468 landmarks per frame. We aggregate 30 frames per round and trim 18% of outliers. Quality gates do the rest. Trained on real faces — not vibes."
        static let startScan = "Start Scan"
        static let history = "History"
        static let recentScans = "Recent scans"
        static let noScansYet = "No scans yet. Run one."
    }

    enum Scan {
        static let countdownPrefix = "Get in frame"
        static let loading = "Loading Camera..."
        static let holdStill = "Hold still"
        static let goodLighting = "Good lighting"
        static let analyzing = "Analyzing…"
        static let cancel = "Cancel"
    }

    enum Faults {
        static let tooDark = "Too dark"
        static let moveCloser = "Move closer"
        static let moveBack = "Move back"
        static let turnLeft = "Turn slightly right" // signed: face turned right means yaw>0; ask user to turn opposite
        static let turnRight = "Turn slightly left"
        static let tiltUp = "Tilt down"
        static let tiltDown = "Tilt up"
        static let holdStill = "Hold still"
        static let noFace = "Show your face"
    }

    enum Results {
        static let titleA = "Verdict"
        static let body = Home.body
        static let scanAgain = "Play Again "
        static let save = "Save"
        static let saved = "Saved"
        static let share = "Share"
        static let qualityGate = "Quality gate"
        static let reliability = "Reliability"
        static let confidence = "Confidence"
        static let trimMean = "Trim mean"
        static let frames = "Frames"
        static let qualityFooter = "Aggregated, normalized, weighted. Same pipeline used in production computer-vision systems."
    }

    enum GameCenter {
        static let personalBest      = "Personal Best"
        static let personalBestShort = "Best"
        static let daily             = "Daily"
        static let allTime           = "All-time"
        static let loading           = "Ranking…"
        static let viewLeaderboards  = "View Leaderboards"
    }

    enum Failure {
        static let title = "Couldn't get a clean read."
        static let body = "Better lighting, hold still, face the camera."
        static let retry = "Try again"
    }

    enum History {
        static let title = "History"
        static let empty = "Your verdicts will land here."
        static let close = "Done"
    }
}
