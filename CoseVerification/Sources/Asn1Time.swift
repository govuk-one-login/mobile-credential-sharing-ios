import Foundation

/// Parses ASN.1 UTCTime and GeneralizedTime values into a `Date`.
///
/// Only the RFC 5280 profile forms are accepted — UTC (`Z`) zone with whole seconds:
/// - **UTCTime** `YYMMDDHHMMSSZ` (13 chars). Two-digit years use the RFC 5280 fixed window:
///   `00–49 → 2000–2049`, `50–99 → 1950–1999` (not a locale-dependent sliding window, which is why
///   this is not delegated to `DateFormatter`).
/// - **GeneralizedTime** `YYYYMMDDHHMMSSZ` (15 chars).
///
/// Any other length, a missing `Z`, or a non-numeric field throws `untrustedCertificate`, matching
/// the strict posture of ``Asn1DerParser``.
enum Asn1Time {

    /// Parses the ASCII contents of a UTCTime (`isUTCTime == true`) or GeneralizedTime element.
    static func date(from content: Data, isUTCTime: Bool) throws -> Date {
        guard let string = String(data: content, encoding: .ascii) else {
            throw CoseVerificationFailure.untrustedCertificate
        }

        // Layout is a year prefix followed by the fixed `MMDDHHMMSS` fields and a `Z`.
        let yearDigits = isUTCTime ? 2 : 4
        guard string.count == yearDigits + 11, string.hasSuffix("Z") else {
            throw CoseVerificationFailure.untrustedCertificate
        }
        let fields = Array(string.dropLast()) // drop 'Z'

        var offset = 0
        let year = try fullYear(twoOrFour(fields, at: &offset, digits: yearDigits), isUTCTime: isUTCTime)
        let month = try twoDigits(fields, at: &offset)
        let day = try twoDigits(fields, at: &offset)
        let hour = try twoDigits(fields, at: &offset)
        let minute = try twoDigits(fields, at: &offset)
        let second = try twoDigits(fields, at: &offset)

        return try makeDate(year: year, month: month, day: day, hour: hour, minute: minute, second: second)
    }

    /// Reads `digits` characters at `offset` (the year field) and advances the offset.
    private static func twoOrFour(_ fields: [Character], at offset: inout Int, digits: Int) -> Substring {
        let slice = Substring(String(fields[offset ..< offset + digits]))
        offset += digits
        return slice
    }

    /// Reads a two-digit field at `offset` and advances the offset past it.
    private static func twoDigits(_ fields: [Character], at offset: inout Int) throws -> Int {
        guard let value = Int(String(fields[offset ..< offset + 2])) else {
            throw CoseVerificationFailure.untrustedCertificate
        }
        offset += 2
        return value
    }

    /// Resolves the four-digit year, applying the RFC 5280 window for two-digit UTCTime years.
    private static func fullYear(_ slice: Substring, isUTCTime: Bool) throws -> Int {
        guard let value = Int(slice) else { throw CoseVerificationFailure.untrustedCertificate }
        guard isUTCTime else { return value }
        return value < 50 ? 2000 + value : 1900 + value
    }

    /// Builds a UTC `Date` from calendar components, rejecting impossible dates. `Calendar` is
    /// lenient (month 13 rolls into the next year), so the components are read back and must match
    /// the input exactly; any roll-over is treated as malformed.
    private static func makeDate(
        year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int
    ) throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt // UTC; non-optional, avoids a force-unwrap
        let requested = DateComponents(
            calendar: calendar, timeZone: calendar.timeZone,
            year: year, month: month, day: day, hour: hour, minute: minute, second: second
        )
        guard let date = requested.date else { throw CoseVerificationFailure.untrustedCertificate }

        let roundTrip = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second], from: date
        )
        guard roundTrip.year == year, roundTrip.month == month, roundTrip.day == day,
              roundTrip.hour == hour, roundTrip.minute == minute, roundTrip.second == second else {
            throw CoseVerificationFailure.untrustedCertificate
        }
        return date
    }
}
