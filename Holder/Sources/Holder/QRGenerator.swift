import CoreImage.CIFilterBuiltins
import UIKit

public enum QRCodeGenerationError: Error {
    case unableToEncodeURL
    case unableToCreateImage
}

public struct QRGenerator {
    let url: String

    public init(url: String) {
        self.url = url
    }

    public func generateQRCode() throws -> UIImage {
        guard let data = url.data(using: .utf8) else {
            throw QRCodeGenerationError.unableToEncodeURL
        }
        let filter = CIFilter.qrCodeGenerator()
        filter.message = data

        let transform = CGAffineTransform(scaleX: 20, y: 20)
        let context = CIContext()
        guard let output = filter.outputImage?.transformed(by: transform),
              let cgImage = context.createCGImage(output, from: output.extent) else {
            throw QRCodeGenerationError.unableToCreateImage
        }
        return UIImage(cgImage: cgImage)
    }
}
