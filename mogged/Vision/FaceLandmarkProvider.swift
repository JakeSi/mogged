import Foundation
import CoreMedia
import UIKit

/// Provider of face landmark frames from a live camera stream.
/// Implementations bridge the underlying engine (MediaPipe, Vision, etc.) into an AsyncStream.
protocol FaceLandmarkProvider: Sendable {
    /// Stream of landmark frames as they become available.
    var frames: AsyncStream<LandmarkFrame> { get }

    /// Submit a sample buffer for processing. May be dropped due to throttling.
    func process(buffer: CMSampleBuffer, orientation: UIImage.Orientation) async
}
