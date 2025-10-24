import CoreImage
@testable import Holder
import SwiftCBOR
import Testing

struct QRGeneratorTests {
    @Test("QR code value matches the URL value")
    func qrCodeValue() throws {
        let data = try CodableCBOREncoder().encode([ 0: "1.0" ])
        let sut = QRGenerator(data: data)

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
        let data = try CodableCBOREncoder().encode([ 0: "1.0" ])
        let sut = QRGenerator(data: data)
        
        #expect(
            sut.url?.absoluteString == "mdoc:oQBjMS4w"
        )
    }
}
