import Foundation
@testable import ISOModels
import Testing

@Suite("DataBase64URLEncoding tests")
struct DataBase64URLEncodingTests {
    @Test("Data is nil when string is non-base 64")
    func nonBase64String() {
        let data = Data(base64URLEncoded: "%12/?hello")
        #expect(data == nil)
    }

    @Test("Data is decoded successfully when padding is missing")
    func base64URLStringMissingPadding() throws {
        let base64URLEncoded = "dGVzdC12YWx1ZQ"
        let data = try #require(Data(base64URLEncoded: base64URLEncoded))
        #expect(data.base64EncodedString() == base64URLEncoded + "==")
    }

    @Test("Data is decoded successfully when dashes are included")
    func base64URLStringWithDashes() throws {
        let base64URLEncoded = "c3VyZS4-"
        let data = try #require(Data(base64URLEncoded: base64URLEncoded))
        #expect(data.base64EncodedString() == "c3VyZS4+")
    }

    @Test("Data is decoded successfully when underscores are included")
    func base64URLStringWithUnderscore() throws {
        let base64URLEncoded = "bGVhc3VyZS4_"
        let data = try #require(Data(base64URLEncoded: base64URLEncoded))
        #expect(data.base64EncodedString() == "bGVhc3VyZS4/")
    }

    @Test("Data is encoded successfully with padding removed")
    func base64URLEncodingWithPadding() throws {
        let data = try #require(Data(base64Encoded: "dGVzdC12YWx1ZQ=="))
        #expect(data.base64URLEncodedString() == "dGVzdC12YWx1ZQ")
    }

    @Test("Data is encoded successfully when pluses are included")
    func base64URLEncodingWithPlus() throws {
        let data = try #require(Data(base64Encoded: "c3VyZS4+"))
        #expect(data.base64URLEncodedString() == "c3VyZS4-")
    }

    @Test("Data is encoded successfully when forward slashes are included")
    func base64URLEncodingWithForwardSlash() throws {
        let data = try #require(Data(base64Encoded: "bGVhc3VyZS4/"))
        #expect(data.base64URLEncodedString() == "bGVhc3VyZS4_")
    }
}
