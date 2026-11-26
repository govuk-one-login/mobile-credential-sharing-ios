import CoreImage
@testable import CredentialSharingUI
import SwiftCBOR
import Testing
import UIKit

struct QRGeneratorTests {
    @Test("QR code encodes the mdoc URL for the given path")
    func qrCodeValue() throws {
        let path = try CodableCBOREncoder().encode([ 0: "1.0" ]).base64URLEncodedString()

        let detector = try #require(CIDetector(
            ofType: CIDetectorTypeQRCode,
            context: nil,
            options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]
        ))
        let image = try #require(CIImage(image: try QRGenerator.generateQRCode(from: path)))
        let qrCodes = detector.features(in: image).compactMap { $0 as? CIQRCodeFeature }
        let qrCodeContent = try #require(qrCodes.first?.messageString)
        #expect(qrCodeContent == "mdoc:oQBjMS4w")
    }

    // MARK: - Quiet zone

    @Test("The image is a valid QR size plus a 4-module quiet zone on every edge")
    func imageIncludesQuietZone() throws {
        let image = try #require(try QRGenerator.generateQRCode(from: "mdoc-payload").cgImage)

        #expect(image.width == image.height)
        let pixelsPerModule = Int(QRGenerator.pixelsPerModule)
        #expect(image.width % pixelsPerModule == 0)

        // A QR code is (17 + 4 × version) modules across, plus the quiet zone on both sides.
        let quietZone = Int(QRGenerator.quietZoneModules)
        let qrModules = image.width / pixelsPerModule - quietZone * 2
        #expect(qrModules >= 21)
        #expect((qrModules - 17) % 4 == 0)
    }

    @Test("The quiet zone is entirely white and the QR modules start right after it")
    func quietZoneIsWhite() throws {
        let image = try #require(try QRGenerator.generateQRCode(from: "mdoc-payload").cgImage)
        let pixels = try RGBAPixels(image)
        let margin = Int(QRGenerator.quietZoneModules * QRGenerator.pixelsPerModule)

        var firstNonWhite: (x: Int, y: Int)?
        scan: for y in 0..<image.height {
            for x in 0..<image.width {
                let inQuietZone = x < margin || y < margin
                    || x >= image.width - margin || y >= image.height - margin
                if inQuietZone && !pixels.isWhite(x: x, y: y) {
                    firstNonWhite = (x, y)
                    break scan
                }
            }
        }
        #expect(firstNonWhite == nil, "Quiet zone pixel \(String(describing: firstNonWhite)) is not white")

        // The first module inside the quiet zone is part of a finder pattern, so it is dark.
        // Sampled at the middle of that module; the finder sits at both top corners and the
        // bottom-left, so this holds whichever way the bitmap is oriented.
        let firstModuleCentre = margin + Int(QRGenerator.pixelsPerModule) / 2
        #expect(!pixels.isWhite(x: firstModuleCentre, y: firstModuleCentre))
    }
}

/// An image redrawn into a known 8-bit RGBA layout so pixels can be read independently of
/// the source image's colour space and byte order.
private struct RGBAPixels {
    struct DrawingError: Error {}
    
    private let width: Int
    private let data: [UInt8]

    init(_ image: CGImage) throws {
        width = image.width
        var data = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let drawn = data.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: image.width,
                height: image.height,
                bitsPerComponent: 8,
                bytesPerRow: image.width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        guard drawn else { throw DrawingError() }
        self.data = data
    }

    func isWhite(x: Int, y: Int) -> Bool {
        let offset = (y * width + x) * 4
        return data[offset] == 255 && data[offset + 1] == 255 && data[offset + 2] == 255
    }
}
