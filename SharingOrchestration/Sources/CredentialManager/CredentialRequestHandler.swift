import ExchangeFormat
import Foundation
import SharingCryptoService
import SharingLogging
import SwiftCBOR

public enum CredentialRequestError: LocalizedError {
    case getCredentialsError
    case noCredentialsReturned
    case msoDecodingFailed
    case docTypeMismatch
    case unsupportedDocumentRequestCount
    case matchedCredentialNotFound
}

// MARK: - Protocols
public protocol CredentialSessionProtocol {
    var matchedCredential: Credential? { get }
    var issuerSigned: IssuerSigned? { get }
    func setMatchedCredential(_ credential: Credential) throws
    func setIssuerSigned(_ issuerSigned: IssuerSigned) throws
}

@MainActor
public protocol CredentialRequestHandlerProtocol {
    func requestAndValidateCredential(for docRequest: RequestedDocument, in session: CredentialSessionProtocol) async throws
    func filterIssuerSigned(for docRequest: RequestedDocument, in session: CredentialSessionProtocol) throws -> FilterResult
    func signSigStructure(in session: CryptoHolderSessionProtocol & CredentialSessionProtocol) async throws
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

    public func requestAndValidateCredential(for docRequest: RequestedDocument, in session: CredentialSessionProtocol) async throws {
        // Derive the credential request only from the authenticated selected
        // DocRequest; the whole DeviceRequest is never consulted here.
        let docType = docRequest.itemsRequest.docType

        let credentials: [Credential]
        do {
            let request = CredentialRequest(documentTypes: [docType])
            credentials = try await credentialProvider.getCredentials(for: request)
        } catch {
            Logger.log("SessionData termination initiated due to getCredentials error thrown", level: .error)
            throw CredentialRequestError.getCredentialsError
        }

        guard let credential = credentials.first else {
            Logger.log("SessionData termination initiated due to getCredentials no credentials returned", level: .error)
            throw CredentialRequestError.noCredentialsReturned
        }

        let parsed: ParsedRawCredential
        do {
            parsed = try rawCredentialParser.parse(rawCredential: credential.rawCredential)
        } catch {
            Logger.log("SessionData termination initiated due to MSO decoding error", level: .error)
            throw CredentialRequestError.msoDecodingFailed
        }

        guard parsed.docType == docType else {
            Logger.log("SessionData termination initiated due to getCredentials no credentials of correct docType returned", level: .error)
            throw CredentialRequestError.docTypeMismatch
        }

        Logger.log("provided credential matches DeviceRequest docType")
        try session.setMatchedCredential(credential)
    }
    
    public func filterIssuerSigned(for docRequest: RequestedDocument, in session: CredentialSessionProtocol) throws -> FilterResult {
        guard let credential = session.matchedCredential else {
            throw CredentialRequestError.matchedCredentialNotFound
        }

        let parsed = try rawCredentialParser.parse(rawCredential: credential.rawCredential)
        let issuerSignedFilter = IssuerSignedFilter()

        // Bridge the authenticated request's parsed namespaces into the filter's
        // request model. Only the selected DocRequest's namespaces are applied.
        let requestedNameSpaces = Self.makeNameSpaces(from: docRequest.itemsRequest.nameSpaces)

        let filterResult = try issuerSignedFilter.filter(
            parsedCredential: parsed,
            requestedNameSpaces: requestedNameSpaces
        )

        // Store the wire model on the session for later response assembly. The
        // full FilterResult (docType + retention) is returned so the caller can
        // deliver the consent-screen details without caching any session data.
        try session.setIssuerSigned(filterResult.issuerSigned)
        return filterResult
    }

    /// Builds the `IssuerSignedFilter` request model from the authenticated
    /// request's parsed namespaces (`[namespace: [element: intentToRetain]]`).
    private static func makeNameSpaces(
        from parsed: [String: [String: Bool]]
    ) -> [NameSpace] {
        parsed.map { namespace, elements in
            NameSpace(
                name: namespace,
                elements: elements.map { identifier, intentToRetain in
                    DataElement(identifier: identifier, intentToRetain: intentToRetain)
                }
            )
        }
    }

    public func signSigStructure(in session: CryptoHolderSessionProtocol & CredentialSessionProtocol) async throws {
        guard let sigStructureBytes = session.sigStructureBytes else {
            throw CryptoServiceError.sigStructureNotFound
        }
        guard let matchedCredentialId = session.matchedCredential?.id else {
            throw CredentialRequestError.matchedCredentialNotFound
        }
        let signatureBytes = try await credentialProvider.sign(payload: sigStructureBytes, documentID: matchedCredentialId)
        try session.setSignatureBytes(signatureBytes)
    }
}
