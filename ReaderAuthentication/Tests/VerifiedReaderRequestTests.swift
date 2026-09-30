@testable import ReaderAuthentication
import Testing

@Suite("VerifiedReaderRequest Tests")
struct VerifiedReaderRequestTests {

    @Test("holds properties and supports equality")
    func holdsPropertiesAndEquality() throws {
        let docRequest1 = try ReaderAuthFixtures.requestedDocument(docType: "org.iso.18013.5.1.mDL")
        let docRequest2 = try ReaderAuthFixtures.requestedDocument(docType: "org.iso.18013.5.1.mDL")
        let cert1 = ReaderAuthFixtures.testCertificate()

        let req1 = VerifiedReaderRequest(docRequest: docRequest1, readerCertificate: cert1)
        let req2 = VerifiedReaderRequest(docRequest: docRequest2, readerCertificate: cert1)

        #expect(req1.docRequest == docRequest1)
        #expect(req1.readerCertificate == cert1)
        #expect(req1 == req2)
    }

    @Test("differs when the docRequest differs")
    func differsByDocRequest() throws {
        let mdl = try ReaderAuthFixtures.requestedDocument(docType: "org.iso.18013.5.1.mDL")
        let photoID = try ReaderAuthFixtures.requestedDocument(docType: "org.iso.23220.2.photoid.1")
        let cert = ReaderAuthFixtures.testCertificate()

        let req1 = VerifiedReaderRequest(docRequest: mdl, readerCertificate: cert)
        let req2 = VerifiedReaderRequest(docRequest: photoID, readerCertificate: cert)

        #expect(req1 != req2)
    }
}
