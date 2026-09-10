@testable import CoseVerification
import Foundation
import Testing

@Suite("ASN.1 time parsing")
struct Asn1TimeTests {

    private func ascii(_ string: String) -> Data { Data(string.utf8) }

    private func components(_ date: Date) -> DateComponents {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
    }

    // MARK: - UTCTime year window (RFC 5280 §4.1.2.5.1)

    @Test("UTCTime year 00–49 maps to 2000–2049")
    func utcTimeYearLowerWindow() throws {
        let date = try Asn1Time.date(from: ascii("260907163526Z"), isUTCTime: true)
        let parts = components(date)
        #expect(parts.year == 2026)
        #expect(parts.month == 9)
        #expect(parts.day == 7)
        #expect(parts.hour == 16)
        #expect(parts.minute == 35)
        #expect(parts.second == 26)
    }

    @Test("UTCTime year 49 is the top of the 2000s window")
    func utcTimeYear49() throws {
        let date = try Asn1Time.date(from: ascii("490101000000Z"), isUTCTime: true)
        #expect(components(date).year == 2049)
    }

    @Test("UTCTime year 50 is the bottom of the 1900s window")
    func utcTimeYear50() throws {
        let date = try Asn1Time.date(from: ascii("500101000000Z"), isUTCTime: true)
        #expect(components(date).year == 1950)
    }

    @Test("UTCTime year 99 maps to 1999")
    func utcTimeYear99() throws {
        let date = try Asn1Time.date(from: ascii("991231235959Z"), isUTCTime: true)
        #expect(components(date).year == 1999)
    }

    // MARK: - GeneralizedTime

    @Test("GeneralizedTime parses a full four-digit year")
    func generalizedTime() throws {
        let date = try Asn1Time.date(from: ascii("20991231235959Z"), isUTCTime: false)
        let parts = components(date)
        #expect(parts.year == 2099)
        #expect(parts.month == 12)
        #expect(parts.second == 59)
    }

    // MARK: - Rejections

    @Test("A missing Z suffix is rejected")
    func missingZone() {
        #expect(throws: CoseVerificationFailure.untrustedCertificate) {
            try Asn1Time.date(from: ascii("260907163526"), isUTCTime: true)
        }
    }

    @Test("A wrong-length string is rejected")
    func wrongLength() {
        #expect(throws: CoseVerificationFailure.untrustedCertificate) {
            try Asn1Time.date(from: ascii("2609Z"), isUTCTime: true)
        }
    }

    @Test("A non-numeric field is rejected")
    func nonNumericField() {
        #expect(throws: CoseVerificationFailure.untrustedCertificate) {
            try Asn1Time.date(from: ascii("2609XX163526Z"), isUTCTime: true)
        }
    }

    @Test("An impossible calendar date (month 13) is rejected")
    func impossibleDate() {
        #expect(throws: CoseVerificationFailure.untrustedCertificate) {
            try Asn1Time.date(from: ascii("261307163526Z"), isUTCTime: true)
        }
    }
}
