import Foundation

protocol CRLProviderProtocol: Sendable {
    var prefetchURLs: [URL] { get }
    
    init() throws(CRLConfigurationError)
    
    func refresh() async throws -> CRLRefreshResult
    func getCrl(for url: URL, forceRevalidation: Bool) async throws -> CrlLookup
}

public final class CRLProvider: CRLProviderProtocol {
    let prefetchURLs: [URL]
    
    /// Loads the CRL configuration from `CredentialSharingCRL.plist` in the main app bundle.
    ///
    /// - Throws: ``CRLConfigurationError/missingResource`` if the host app does not bundle the file,
    ///   or ``CRLConfigurationError/invalidResource(reason:)`` if it cannot be read or is invalid.
    public convenience init() throws(CRLConfigurationError) {
        try self.init(
            configurationURL: Bundle.main.url(
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
        return .ready
    }
   
    func getCrl(for url: URL, forceRevalidation: Bool) async throws -> CrlLookup {
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

internal enum CrlLookup: Sendable {
    case available(Data)
    case unavailable(CrlLookupFailure)
}

internal enum CrlLookupFailure: Sendable {
    case network, storage, response
}
