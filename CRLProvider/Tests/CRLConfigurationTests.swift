import Foundation
import Testing

@testable import CRLProvider

@Suite("CRL configuration loading")
struct CRLConfigurationTests {
    // MARK: - Invalid resource

    struct InvalidCase: Sendable, CustomTestStringConvertible {
        let name: String
        let contents: String
        let expectedReason: String

        var testDescription: String { name }
    }

    static let invalidCases: [InvalidCase] = [
        InvalidCase(
            name: "not a property list",
            contents: "this is not a plist",
            expectedReason: "is not a valid property list"
        ),
        InvalidCase(
            name: "root is not a dictionary",
            contents: wrap("<array/>"),
            expectedReason: "dictionary at its root"
        ),
        InvalidCase(
            name: "prefetchURLs key is missing",
            contents: wrap("<dict/>"),
            expectedReason: "missing the 'prefetchURLs' key"
        ),
        InvalidCase(
            name: "prefetchURLs is not an array",
            contents: wrap("<dict><key>prefetchURLs</key><string>http://example.com/a.crl</string></dict>"),
            expectedReason: "must be an array of strings"
        ),
        InvalidCase(
            name: "prefetchURLs contains a non-string",
            contents: wrap("<dict><key>prefetchURLs</key><array><integer>1</integer></array></dict>"),
            expectedReason: "must be an array of strings"
        ),
        InvalidCase(
            name: "a value is not a URL",
            contents: urlsPlist(["http://example.com/a.crl", "not a url"]),
            expectedReason: "prefetchURLs[1] is not a valid HTTP(S) URL: \"not a url\""
        ),
        InvalidCase(
            name: "a value is not HTTP or HTTPS",
            contents: urlsPlist(["ftp://example.com/a.crl"]),
            expectedReason: "prefetchURLs[0] is not a valid HTTP(S) URL: \"ftp://example.com/a.crl\""
        ),
        InvalidCase(
            name: "a value has no host",
            contents: urlsPlist(["http://"]),
            expectedReason: "prefetchURLs[0] is not a valid HTTP(S) URL"
        )
    ]
    
    // MARK: - Valid configuration

    @Test("Loads the configured URLs in file order")
    func loadsConfiguredURLs() throws {
        let url = try makePlistFile(urlsPlist([
            "http://root.verifier-root-ca.integration.account.gov.uk/crl/3689017a-d5f2-4762-b518-afb86983dd25.crl",
            "https://dvs.verifier-ca.integration.account.gov.uk/crl/85b2ae92-97ab-406b-93b2-f765795de390.crl"
        ]))
        defer { try? FileManager.default.removeItem(at: url) }

        let sut = try CRLProvider(configurationURL: url)

        #expect(sut.prefetchURLs.map(\.absoluteString) == [
            "http://root.verifier-root-ca.integration.account.gov.uk/crl/3689017a-d5f2-4762-b518-afb86983dd25.crl",
            "https://dvs.verifier-ca.integration.account.gov.uk/crl/85b2ae92-97ab-406b-93b2-f765795de390.crl"
        ])
    }

    @Test("An empty prefetchURLs array is allowed")
    func allowsEmptyArray() throws {
        let url = try makePlistFile(urlsPlist([]))
        defer { try? FileManager.default.removeItem(at: url) }

        let sut = try CRLProvider(configurationURL: url)

        #expect(sut.prefetchURLs.isEmpty)
    }

    @Test("The URL scheme is matched case-insensitively")
    func acceptsUppercaseScheme() throws {
        let url = try makePlistFile(urlsPlist(["HTTP://example.com/a.crl"]))
        defer { try? FileManager.default.removeItem(at: url) }

        let sut = try CRLProvider(configurationURL: url)

        #expect(sut.prefetchURLs.count == 1)
    }

    // MARK: - Missing resource

    @Test("A missing plist throws missingResource")
    func missingPlistThrowsMissingResource() {
        #expect(configurationError(forURL: nil) == .missingResource)
    }

    @Test(
        "Invalid configuration throws invalidResource with a diagnostic reason",
        arguments: CRLConfigurationTests.invalidCases
    )
    func invalidConfigurationThrows(testCase: InvalidCase) throws {
        let url = try makePlistFile(testCase.contents)
        defer { try? FileManager.default.removeItem(at: url) }

        guard case .invalidResource(let reason)? = configurationError(forURL: url) else {
            Issue.record("Expected invalidResource for: \(testCase.name)")
            return
        }
        #expect(reason.contains(testCase.expectedReason), "Unexpected reason: \(reason)")
    }

    @Test("A file that cannot be read throws invalidResource")
    func unreadableFileThrowsInvalidResource() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).plist")

        guard case .invalidResource(let reason)? = configurationError(forURL: url) else {
            Issue.record("Expected invalidResource")
            return
        }
        #expect(reason.contains("Could not read"))
    }
}

// MARK: - Helpers

private func configurationError(forURL url: URL?) -> CRLConfigurationError? {
    let result = Result { try CRLProvider(configurationURL: url) }
    guard case .failure(let error) = result else { return nil }
    return error as? CRLConfigurationError
}

private func makePlistFile(_ contents: String) throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).plist")
    try Data(contents.utf8).write(to: url)
    return url
}

private func wrap(_ body: String) -> String {
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    \(body)
    </plist>
    """
}

private func urlsPlist(_ urls: [String]) -> String {
    let strings = urls.map { "<string>\($0)</string>" }.joined()
    return wrap("<dict><key>prefetchURLs</key><array>\(strings)</array></dict>")
}
