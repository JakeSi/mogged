import Foundation
import CoreVideo

enum MeanLuma {
    /// Computes mean luma of a BGRA pixel buffer in [0, 1] by sparse sampling.
    static func compute(pixelBuffer: CVPixelBuffer) -> Float {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return 0.5 }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let ptr = base.assumingMemoryBound(to: UInt8.self)

        let step = 32
        var sum: Float = 0
        var count: Float = 0

        var y = 0
        while y < height {
            var x = 0
            while x < width {
                let offset = y * bytesPerRow + x * 4 // BGRA
                let b = Float(ptr[offset])
                let g = Float(ptr[offset + 1])
                let r = Float(ptr[offset + 2])
                sum += 0.299 * r + 0.587 * g + 0.114 * b
                count += 1
                x += step
            }
            y += step
        }

        return count > 0 ? (sum / count) / 255.0 : 0.5
    }
}
