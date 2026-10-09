import ExchangeFormat
import Foundation
import SharingCryptoService
@testable import SharingOrchestration

class MockCredentialRequestHandler: CredentialRequestHandlerProtocol {
    var errorToThrow: Error?
    var signErrorToThrow: Error?
    var filterErrorToThrow: Error?
    var stubbedSignatureBytes: Data = Data([0x01, 0x02])
    var stubbedFilterResult: FilterResult = FilterResult(
        issuerSigned: IssuerSigned(nameSpaces: [:], issuerAuth: []),
        docType: "org.iso.18013.5.1.mDL",
        retention: [:]
    )
    var didCallSignSigStructure = false
    var didCallFilterIssuerSigned = false
    private(set) var filteredDocRequest: RequestedDocument?

    func requestAndValidateCredential(for docRequest: RequestedDocument, in session: CredentialSessionProtocol) async throws {
        if let errorToThrow {
            throw errorToThrow
        }
    }

    func signSigStructure(in session: CryptoHolderSessionProtocol & CredentialSessionProtocol) async throws {
        didCallSignSigStructure = true
        if let signErrorToThrow { throw signErrorToThrow }
        if let errorToThrow { throw errorToThrow }
        try session.setSignatureBytes(stubbedSignatureBytes)
    }

    func filterIssuerSigned(for docRequest: RequestedDocument, in session: any SharingOrchestration.CredentialSessionProtocol) throws -> FilterResult {
        didCallFilterIssuerSigned = true
        filteredDocRequest = docRequest
        if let filterErrorToThrow {
            throw filterErrorToThrow
        }
        return stubbedFilterResult
    }
}
