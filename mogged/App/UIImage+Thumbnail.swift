import UIKit

extension UIImage {
    /// Resizes to fit within `maxDimension` × `maxDimension`, then encodes as JPEG at 0.7 quality.
    func cappedThumbnail(maxDimension: CGFloat) -> Data? {
        let scale = min(maxDimension / size.width, maxDimension / size.height, 1)
        let targetSize = scale < 1
            ? CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
            : size
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in draw(in: CGRect(origin: .zero, size: targetSize)) }
        return resized.jpegData(compressionQuality: 0.7)
    }
}
