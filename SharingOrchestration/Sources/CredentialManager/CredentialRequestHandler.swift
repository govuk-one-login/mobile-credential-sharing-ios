import Foundation
import SharingCryptoService
import SwiftCBOR

public enum CredentialRequestError: LocalizedError {
    case getCredentialsError
    case noCredentialsReturned
    case msoDecodingFailed
    case docTypeMismatch
}

@MainActor
public protocol CredentialRequestHandlerProtocol {
    func requestAndValidate(for deviceRequest: DeviceRequest) async throws -> Data
}

@MainActor
public struct CredentialRequestHandler: CredentialRequestHandlerProtocol {
    private let credentialProvider: CredentialProvider

    public init(credentialProvider: CredentialProvider) {
        self.credentialProvider = credentialProvider
    }

    public func requestAndValidate(for deviceRequest: DeviceRequest) async throws -> Data {
        let docType = deviceRequest.docRequests[0].itemsRequest.docType.rawValue

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

        let msoDocType: String
        do {
            msoDocType = try extractDocType(from: credential.rawCredential)
        } catch {
            print("SessionData termination initiated due to MSO decoding error")
            throw CredentialRequestError.msoDecodingFailed
        }

        guard msoDocType == docType else {
            print("SessionData termination initiated due to getCredentials no credentials of correct docType returned")
            throw CredentialRequestError.docTypeMismatch
        }

        print("provided credential matches DeviceRequest docType")
        return credential.rawCredential
    }

    private func extractDocType(from rawCredential: Data) throws -> String {
        guard let cbor = try CBOR.decode([UInt8](rawCredential)),
              case .map(let root) = cbor,
              case .array(let issuerAuth) = root[.issuerAuth],
              issuerAuth.count >= 3,
              case .byteString(let payload) = issuerAuth[2],
              let payloadCBOR = try CBOR.decode(payload),
              case .tagged(.encodedCBORDataItem, .byteString(let msoBytes)) = payloadCBOR,
              let msoCBOR = try CBOR.decode(msoBytes),
              case .map(let mso) = msoCBOR,
              case .utf8String(let docType) = mso[.docType]
        else {
            throw CredentialRequestError.msoDecodingFailed
        }
        return docType
    }
}

private extension CBOR {
    static var issuerAuth: CBOR { "issuerAuth" }
    static var docType: CBOR { "docType" }
}
