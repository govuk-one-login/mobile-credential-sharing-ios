import CoreImage
@testable import CredentialSharingUI
import SwiftCBOR
import Testing

struct QRGeneratorTests {
    @Test("QR code value matches the URL value")
    func qrCodeValue() throws {
        let path = try CodableCBOREncoder().encode([ 0: "1.0" ]).base64URLEncodedString()
        let sut = QRGenerator(path: path)

        let detector = try #require(CIDetector(
            ofType: CIDetectorTypeQRCode,
            context: nil,
            options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]
        ))
        let image = try #require(CIImage(image: sut.generateQRCode()))
        let qrCodes = detector.features(in: image).compactMap { $0 as? CIQRCodeFeature }
        let qrCodeContent = try #require(qrCodes.first?.messageString)
        #expect(qrCodeContent == sut.url?.absoluteString)
    }
    
    @Test("Correctly builds the URL")
    func buildsURL() throws {
        let path = try CodableCBOREncoder().encode([ 0: "1.0" ]).base64URLEncodedString()
        let sut = QRGenerator(path: path)
        
        #expect(
            sut.url?.absoluteString == "mdoc:oQBjMS4w"
        )
    }
}
