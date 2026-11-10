import CoreImage.CIFilterBuiltins
import UIKit

public enum QRCodeGenerationError: Error {
    case unableToEncodeURL
    case unableToCreateImage
}

public struct QRGenerator {
    var url: URL? {
        var components = URLComponents()
        components.scheme = "mdoc"
        components.path = path
        return components.url
    }
    
    let path: String

    public init(path: String) {
        self.path = path
    }

    public func generateQRCode() throws -> UIImage {
        guard let data = url?.dataRepresentation else {
            throw QRCodeGenerationError.unableToEncodeURL
        }
        let filter = CIFilter.qrCodeGenerator()
        filter.message = data

        let context = CIContext()
        guard let rawOutput = filter.outputImage else {
            throw QRCodeGenerationError.unableToCreateImage
        }

        // CoreImage's QR generator bakes a 1-module-wide "quiet zone" (white
        // border) into every edge of the output. Left in, that border makes the
        // visible QR appear inset from the surrounding layout. The screen's own
        // white background provides the quiet zone a scanner needs, so crop the
        // baked-in border to the QR modules before scaling up.
        let quietZoneModules: CGFloat = 1
        let croppedExtent = rawOutput.extent.insetBy(
            dx: quietZoneModules,
            dy: quietZoneModules
        )
        let cropped = rawOutput
            .cropped(to: croppedExtent)
            // Re-origin to (0,0) so the scale transform maps cleanly.
            .transformed(by: CGAffineTransform(
                translationX: -croppedExtent.origin.x,
                y: -croppedExtent.origin.y
            ))

        let transform = CGAffineTransform(scaleX: 20, y: 20)
        guard let output = cropped.transformed(by: transform) as CIImage?,
              let cgImage = context.createCGImage(output, from: output.extent) else {
            throw QRCodeGenerationError.unableToCreateImage
        }
        return UIImage(cgImage: cgImage)
    }
}
