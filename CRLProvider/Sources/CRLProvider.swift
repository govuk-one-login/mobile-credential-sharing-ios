import Foundation

protocol CRLProviderProtocol: Sendable {
    var prefetchURLs: [String] { get }
    
    init() throws(CRLConfigurationError)
    
    func refresh() async throws -> CRLRefreshResult
    func getCrl(for url: URL, forceRevalidation: Bool) async throws -> CrlLookup
}

public final class CRLProvider: CRLProviderProtocol {
    let prefetchURLs: [String]
    
    public init() throws(CRLConfigurationError) {
        prefetchURLs = ["Get these from .plist"]
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
