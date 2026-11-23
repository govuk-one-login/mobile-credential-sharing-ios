import CoreImage
@testable import CredentialSharingUI
import SwiftCBOR
import Testing

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
}
