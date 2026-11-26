import Foundation

/// Reads the CRL configuration the host app bundles as `CredentialSharingCRL.plist`.
enum CRLConfiguration {
    static let resourceName = "CredentialSharingCRL"
    static let resourceExtension = "plist"
    static let prefetchURLsKey = "prefetchURLs"

    /// Loads and validates `prefetchURLs` from the plist at `url`.
    ///
    /// - Returns: The configured URLs, in file order. An empty array is valid.
    /// - Throws: `CRLConfigurationError.invalidResource` if the file cannot be read, is not a
    ///   property list, has no `prefetchURLs` array of strings, or contains a value that is not
    ///   a valid HTTP or HTTPS URL. The reason identifies the problem.
    static func loadPrefetchURLs(from url: URL) throws(CRLConfigurationError) -> [URL] {
        let fileName = url.lastPathComponent

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw .invalidResource(reason: "Could not read \(fileName): \(error.localizedDescription)")
        }

        let propertyList: Any
        do {
            propertyList = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        } catch {
            throw .invalidResource(reason: "\(fileName) is not a valid property list: \(error.localizedDescription)")
        }

        guard let dictionary = propertyList as? [String: Any] else {
            throw .invalidResource(reason: "\(fileName) must contain a dictionary at its root")
        }
        guard let value = dictionary[prefetchURLsKey] else {
            throw .invalidResource(reason: "\(fileName) is missing the '\(prefetchURLsKey)' key")
        }
        guard let strings = value as? [String] else {
            throw .invalidResource(reason: "'\(prefetchURLsKey)' in \(fileName) must be an array of strings")
        }

        var urls: [URL] = []
        for (index, string) in strings.enumerated() {
            guard let url = httpURL(from: string) else {
                throw .invalidResource(reason: "\(prefetchURLsKey)[\(index)] is not a valid HTTP(S) URL: \"\(string)\"")
            }
            urls.append(url)
        }
        return urls
    }

    /// A valid configuration value is an `http` or `https` URL with a host.
    private static func httpURL(from string: String) -> URL? {
        guard let components = URLComponents(string: string),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = components.host, !host.isEmpty else {
            return nil
        }
        return components.url
    }
}
