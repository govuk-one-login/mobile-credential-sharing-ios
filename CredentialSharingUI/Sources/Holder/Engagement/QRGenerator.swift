import CoreImage.CIFilterBuiltins
import UIKit

public enum QRCodeGenerationError: Error {
    case unableToEncodeURL
    case unableToCreateImage
}

public enum QRGenerator {
    private static let context = CIContext()

    /// Quiet zone, in modules, on every edge of the returned image (the QR standard's minimum).
    static let quietZoneModules: CGFloat = 4

    /// Pixels each QR module is scaled to in the returned image.
    static let pixelsPerModule: CGFloat = 20

    /// Quiet zone CoreImage already includes on every edge of its output.
    private static let generatedQuietZoneModules: CGFloat = 1

    public static func generateQRCode(from path: String) throws -> UIImage {
        var url: URL? {
            var components = URLComponents()
            components.scheme = "mdoc"
            components.path = path
            return components.url
        }
        
        guard let data = url?.dataRepresentation else {
            throw QRCodeGenerationError.unableToEncodeURL
        }
        let filter = CIFilter.qrCodeGenerator()
        filter.message = data

        guard let rawOutput = filter.outputImage else {
            throw QRCodeGenerationError.unableToCreateImage
        }

        // CoreImage's QR generator bakes a 1-module-wide quiet zone (white border) into
        // every edge of the output, but a scanner needs 4 modules. Extend the output with
        // opaque white to a 4-module quiet zone on every edge. The quiet zone is part of the
        // image (not layout padding) so it stays exactly 4 modules at any rendered size, and
        // stays white in dark mode.
        let extraModules = Self.quietZoneModules - Self.generatedQuietZoneModules
        let paddedExtent = rawOutput.extent.insetBy(dx: -extraModules, dy: -extraModules)
        let whiteBackground = CIImage(color: .white).cropped(to: paddedExtent)
        let padded = rawOutput
            .composited(over: whiteBackground)
            // Re-origin to (0,0) so the scale transform maps cleanly.
            .transformed(by: CGAffineTransform(
                translationX: -paddedExtent.origin.x,
                y: -paddedExtent.origin.y
            ))

        let transform = CGAffineTransform(scaleX: Self.pixelsPerModule, y: Self.pixelsPerModule)
        guard let output = padded.transformed(by: transform) as CIImage?,
              let cgImage = context.createCGImage(output, from: output.extent) else {
            throw QRCodeGenerationError.unableToCreateImage
        }
        return UIImage(cgImage: cgImage)
    }
}
