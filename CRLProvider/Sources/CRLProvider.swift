import Foundation

protocol CRLProviderProtocol: Sendable {
    var prefetchURLs: [URL] { get }
    
    init() throws(CRLConfigurationError)
    
    func refresh() async throws -> CRLRefreshResult
    func getCRL(for url: URL, forceRevalidation: Bool) async throws -> CRLLookup
}

public final class CRLProvider: CRLProviderProtocol {
    let prefetchURLs: [URL]
    
    /// Loads the CRL configuration from `CredentialSharingCRL.plist` in the main app bundle.
    ///
    /// - Throws: ``CRLConfigurationError/missingResource`` if the host app does not bundle the file,
    ///   or ``CRLConfigurationError/invalidResource(reason:)`` if it cannot be read or is invalid.
    public convenience init() throws(CRLConfigurationError) {
        try self.init(bundle: .main)
    }
    
    /// - Parameter bundle: The bundle that should contain `CredentialSharingCRL.plist`.
    convenience init(bundle: Bundle) throws(CRLConfigurationError) {
        try self.init(
            configurationURL: bundle.url(
                forResource: CRLConfiguration.resourceName,
                withExtension: CRLConfiguration.resourceExtension
            )
        )
    }
    
    /// - Parameter configurationURL: The configuration plist, or `nil` if the host app has none.
    init(configurationURL: URL?) throws(CRLConfigurationError) {
        guard let configurationURL else {
            throw .missingResource
        }
        prefetchURLs = try CRLConfiguration.loadPrefetchURLs(from: configurationURL)
    }
    
    @discardableResult
    public func refresh() async throws -> CRLRefreshResult {
        // TODO: DCMAW-24669 Implement in refresh ticket
        return .ready
    }
   
    func getCRL(for url: URL, forceRevalidation: Bool) async throws -> CRLLookup {
        // TODO: DCMAW-24667 Implement in getCrl ticket
        return .available(Data())
    }
}

public enum CRLRefreshResult: Equatable, Sendable {
    case ready, updateRequired
}

public enum CRLConfigurationError: Error, Equatable, Sendable {
    case missingResource
    case invalidResource(reason: String)
}

internal enum CRLLookup: Sendable {
    case available(Data)
    case unavailable(CRLLookupFailure)
}

internal enum CRLLookupFailure: Sendable {
    case network, storage, response
}
