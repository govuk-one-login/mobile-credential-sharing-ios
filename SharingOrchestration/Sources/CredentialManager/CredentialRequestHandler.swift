import Foundation
import SharingCryptoService
import SwiftCBOR

public enum CredentialRequestError: LocalizedError {
    case getCredentialsError
    case noCredentialsReturned
    case msoDecodingFailed
    case docTypeMismatch
    case unsupportedDocumentRequestCount
}

@MainActor
public protocol CredentialRequestHandlerProtocol {
    func requestAndValidate(for deviceRequest: DeviceRequest) async throws
}

public struct CredentialRequestHandler: CredentialRequestHandlerProtocol {
    private let credentialProvider: CredentialProvider
    private let rawCredentialParser: RawCredentialParser

    public init(
        credentialProvider: CredentialProvider,
        rawCredentialParser: RawCredentialParser = RawCredentialParser()
    ) {
        self.credentialProvider = credentialProvider
        self.rawCredentialParser = rawCredentialParser
    }

    public func requestAndValidate(for deviceRequest: DeviceRequest) async throws {
        // We are only covering a single docRequest for now.
        // Logic to handle multiple docRequests to be implemented in future.
        guard deviceRequest.docRequests.count == 1,
            let docRequest = deviceRequest.docRequests.first else {
            throw CredentialRequestError.unsupportedDocumentRequestCount
        }
        let docType = docRequest.itemsRequest.docType.rawValue

        let credentials: [Credential]
        do {
            let request = CredentialRequest(documentTypes: [docType])
            credentials = try await credentialProvider.getCredentials(for: request)
        } catch {
            print("SessionData termination initiated due to getCredentials error thrown")
            throw CredentialRequestError.getCredentialsError
        }

        guard let credential = credentials.first else {
            print("SessionData termination initiated due to getCredentials no credentials returned")
            throw CredentialRequestError.noCredentialsReturned
        }

        let parsed: ParsedRawCredential
        do {
            parsed = try rawCredentialParser.parse(rawCredential: credential.rawCredential)
        } catch {
            print("SessionData termination initiated due to MSO decoding error")
            throw CredentialRequestError.msoDecodingFailed
        }

        guard parsed.docType == docType else {
            print("SessionData termination initiated due to getCredentials no credentials of correct docType returned")
            throw CredentialRequestError.docTypeMismatch
        }

        print("provided credential matches DeviceRequest docType")
    }
}
