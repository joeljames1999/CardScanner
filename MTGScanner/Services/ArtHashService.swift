import UIKit
import Accelerate

// MARK: - ArtHashService
// Generates perceptual hashes (pHash) of card art crops.
// Stores hashes lazily in SQLite as cards are scanned.
// On scan, finds the closest matching hash via Hamming distance.

final class ArtHashService {

    static let shared = ArtHashService()
    private init() {}

    // MARK: - Perceptual Hash

    /// Generate a 64-bit perceptual hash from a UIImage.
    /// Resize to 32x32, convert to greyscale, apply DCT, compare to median.
    func pHash(of image: UIImage) -> UInt64? {
        guard let resized = resize(image, to: CGSize(width: 32, height: 32)),
              let grey = toGreyscalePixels(resized) else { return nil }

        // 2D DCT — we only need the top-left 8x8 of the 32x32 result
        let dct = dct2D(grey, size: 32)
        let topLeft = Array(dct.prefix(64)) // 8x8 = 64 values

        let median = topLeft.sorted()[32]

        var hash: UInt64 = 0
        for (i, val) in topLeft.enumerated() {
            if val > median {
                hash |= (1 << i)
            }
        }
        return hash
    }

    /// Hamming distance between two hashes — lower = more similar.
    /// 0 = identical, > 15 = likely different card.
    func hammingDistance(_ a: UInt64, _ b: UInt64) -> Int {
        (a ^ b).nonzeroBitCount
    }

    // MARK: - Art Crop
    // MTG card art occupies roughly the top 45% of the card, with small insets.

    func cropArtRegion(from image: UIImage) -> UIImage? {
        let size = image.size

        // MTG card art box — tuned to full perspective-corrected card
        // Top of art: ~10% from top (below name bar)
        // Bottom of art: ~55% from top (above type line)
        // Sides: ~6% inset each side
        let rect = CGRect(
            x: size.width  * 0.06,
            y: size.height * 0.10,
            width:  size.width  * 0.88,
            height: size.height * 0.42
        )

        guard let cgImage = image.cgImage?.cropping(to: CGRect(
            x:      rect.origin.x    * image.scale,
            y:      rect.origin.y    * image.scale,
            width:  rect.width       * image.scale,
            height: rect.height      * image.scale
        )) else { return nil }

        return UIImage(cgImage: cgImage)
    }

    // MARK: - Download & Hash a card's art image

    func downloadAndHash(imageURL: URL) async -> UInt64? {
        guard let (data, _) = try? await URLSession.shared.data(from: imageURL),
              let image = UIImage(data: data),
              let crop  = cropArtRegion(from: image) else { return nil }
        return pHash(of: crop)
    }

    // MARK: - Private DSP Helpers

    private func resize(_ image: UIImage, to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, true, 1.0)
        image.draw(in: CGRect(origin: .zero, size: size))
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return result
    }

    private func toGreyscalePixels(_ image: UIImage) -> [Float]? {
        guard let cgImage = image.cgImage else { return nil }
        let width  = cgImage.width
        let height = cgImage.height
        var pixels = [UInt8](repeating: 0, count: width * height)

        guard let ctx = CGContext(
            data: &pixels,
            width: width, height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }

        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixels.map { Float($0) / 255.0 }
    }

    private func dct2D(_ input: [Float], size: Int) -> [Float] {
        var result = [Float](repeating: 0, count: size * size)

        // Apply 1D DCT to each row
        var rowDCT = [Float](repeating: 0, count: size * size)
        for row in 0..<size {
            var rowData = Array(input[row * size ..< row * size + size])
            dct1D(&rowData, length: size)
            for col in 0..<size {
                rowDCT[row * size + col] = rowData[col]
            }
        }

        // Apply 1D DCT to each column
        for col in 0..<size {
            var colData = (0..<size).map { rowDCT[$0 * size + col] }
            dct1D(&colData, length: size)
            for row in 0..<size {
                result[row * size + col] = colData[row]
            }
        }

        return result
    }

    private func dct1D(_ data: inout [Float], length: Int) {
        // Type-II DCT using vDSP
        var output = [Float](repeating: 0, count: length)
        let n = vDSP_Length(length)
        data.withUnsafeBufferPointer { inPtr in
            output.withUnsafeMutableBufferPointer { outPtr in
                vDSP_DCT_Execute(
                    vDSP_DCT_CreateSetup(nil, n, .II)!,
                    inPtr.baseAddress!,
                    outPtr.baseAddress!
                )
            }
        }
        data = output
    }
}
