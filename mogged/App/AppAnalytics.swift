import FirebaseAnalytics

enum AppAnalytics {
    static func scanStarted() {
        Analytics.logEvent("scan_started", parameters: nil)
    }

    static func scanCompleted(result: ScanResult) {
        Analytics.logEvent("scan_completed", parameters: [
            "harmony_score": (result.harmony * 100).rounded() / 100,
            "tier": result.tier.rawValue
        ])
    }

    static func scanFailed(reason: String) {
        Analytics.logEvent("scan_failed", parameters: [
            "reason": reason
        ])
    }

    static func scanCancelled() {
        Analytics.logEvent("scan_cancelled", parameters: nil)
    }

    static func scanRetried() {
        Analytics.logEvent("scan_retried", parameters: nil)
    }

    static func resultSaved() {
        Analytics.logEvent("result_saved", parameters: nil)
    }

    static func resultShared() {
        Analytics.logEvent("result_shared", parameters: nil)
    }

    static func leaderboardViewed() {
        Analytics.logEvent("leaderboard_viewed", parameters: nil)
    }
}
