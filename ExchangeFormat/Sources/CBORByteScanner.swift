import Foundation

/// Walks raw CBOR bytes to find the exact byte range each item occupies,
/// without decoding those bytes into model objects.
///
/// Why this exists: ISO 18013-5 signs the bytes exactly as *received*. Two
/// problems make SwiftCBOR unsuitable for that:
///   - `CBOR.decode` returns a value tree with no record of where each item
///     started or ended in the input.
///   - Re-encoding a decoded value can produce different-but-equivalent bytes
///     (CBOR permits some non-canonical encodings), which would invalidate a
///     signature.
/// To keep the signed bytes intact, this scanner reports the original ranges so
/// callers can slice them straight out of the input.
///
/// This type is the single source of truth for structural framing. It can:
///   - find the range of one complete item (`scanItem`),
///   - list the ranges of a map's key/value entries (`mapEntries`),
///   - list the ranges of an array's elements (`arrayElements`).
/// It does not read payloads, enforce canonical ordering, or apply semantic
/// rules — the decoder handles all of that. Indefinite-length items are
/// rejected: ISO request encodings are always definite-length, so there is no
/// need to support break-terminated items.
enum CBORByteScanner {

    /// The half-open byte range `[start, end)` that one complete item occupies.
    struct ItemRange: Equatable {
        let start: Int
        let end: Int
        var length: Int { end - start }
    }

    /// One map entry, expressed as the byte ranges of its key and its value.
    struct MapEntry: Equatable {
        let key: ItemRange
        let value: ItemRange
    }

    // MARK: - Single item

    /// Finds the byte range of one complete CBOR item starting at `offset`.
    ///
    /// - Parameters:
    ///   - bytes: The full input buffer.
    ///   - offset: The index where the item begins.
    /// - Returns: The `[start, end)` range the item occupies.
    /// - Throws: `ExchangeFormatError.malformedStructure` if the framing is
    ///   malformed, truncated, or uses an unsupported (indefinite-length) form.
    static func scanItem(_ bytes: [UInt8], at offset: Int) throws -> ItemRange {
        let end = try scanEnd(bytes, at: offset)
        return ItemRange(start: offset, end: end)
    }

    // MARK: - Collections

    /// Lists the entries of a definite-length map at `offset`, returning the
    /// byte ranges of each key and value in the order they appear.
    ///
    /// - Throws: `ExchangeFormatError.malformedStructure` if the item at `offset`
    ///   is not a definite-length map.
    static func mapEntries(_ bytes: [UInt8], at offset: Int) throws -> [MapEntry] {
        let (majorType, count, headerSize) = try header(bytes, at: offset)
        guard majorType == 5 else { // major type 5 == map
            throw ExchangeFormatError.malformedStructure
        }

        var position = offset + headerSize
        var entries: [MapEntry] = []
        entries.reserveCapacity(count)
        for _ in 0..<count {
            let key = try scanItem(bytes, at: position)
            let value = try scanItem(bytes, at: key.end)
            entries.append(MapEntry(key: key, value: value))
            position = value.end
        }
        return entries
    }

    /// Lists the elements of a definite-length array at `offset`, returning the
    /// byte range of each element in order.
    ///
    /// - Throws: `ExchangeFormatError.malformedStructure` if the item at `offset`
    ///   is not a definite-length array.
    static func arrayElements(_ bytes: [UInt8], at offset: Int) throws -> [ItemRange] {
        let (majorType, count, headerSize) = try header(bytes, at: offset)
        guard majorType == 4 else { // major type 4 == array
            throw ExchangeFormatError.malformedStructure
        }

        var position = offset + headerSize
        var elements: [ItemRange] = []
        elements.reserveCapacity(count)
        for _ in 0..<count {
            let element = try scanItem(bytes, at: position)
            elements.append(element)
            position = element.end
        }
        return elements
    }

    // MARK: - Framing

    /// Returns the index just past the last byte of the item starting at `offset`.
    private static func scanEnd(_ bytes: [UInt8], at offset: Int) throws -> Int {
        let (majorType, argument, headerSize) = try header(bytes, at: offset)

        switch majorType {
        case 0, 1, 7: // integer / simple / float: fully described by the header
            return offset + headerSize

        case 2, 3: // byte string / text string: header + `argument` payload bytes
            let end = offset + headerSize + argument
            try requireWithinBounds(end, in: bytes)
            return end

        case 4: // array: `argument` elements follow the header
            var position = offset + headerSize
            for _ in 0..<argument {
                position = try scanEnd(bytes, at: position)
            }
            return position

        case 5: // map: `argument` key/value pairs follow the header
            var position = offset + headerSize
            for _ in 0..<argument {
                position = try scanEnd(bytes, at: position) // key
                position = try scanEnd(bytes, at: position) // value
            }
            return position

        case 6: // tagged item: tag header, then one nested item
            return try scanEnd(bytes, at: offset + headerSize)

        default:
            throw ExchangeFormatError.malformedStructure
        }
    }

    /// Reads the header of the item at `offset` and returns three things:
    ///   - `majorType`: the CBOR major type (0-7).
    ///   - `argument`: the number encoded in the header — a length for strings,
    ///     an element count for arrays/maps, or the value itself for small
    ///     integers.
    ///   - `headerSize`: how many bytes the header takes up.
    ///
    /// Rejects indefinite-length and reserved additional-info values (28...31),
    /// and 64-bit arguments (additional info 27) that don't fit in an `Int`.
    private static func header(_ bytes: [UInt8], at offset: Int) throws -> (majorType: UInt8, argument: Int, headerSize: Int) {
        guard offset >= 0, offset < bytes.count else {
            throw ExchangeFormatError.malformedStructure
        }

        let initial = bytes[offset]
        let majorType = initial >> 5
        let additionalInfo = initial & 0x1F

        switch additionalInfo {
        case 0...23:
            return (majorType, Int(additionalInfo), 1)
        case 24:
            try requireWithinBounds(offset + 2, in: bytes)
            return (majorType, Int(bytes[offset + 1]), 2)
        case 25:
            try requireWithinBounds(offset + 3, in: bytes)
            let value = Int(bytes[offset + 1]) << 8 | Int(bytes[offset + 2])
            return (majorType, value, 3)
        case 26:
            try requireWithinBounds(offset + 5, in: bytes)
            var value = 0
            for i in 1...4 { value = value << 8 | Int(bytes[offset + i]) }
            return (majorType, value, 5)
        case 27:
            try requireWithinBounds(offset + 9, in: bytes)
            var value: UInt64 = 0
            for i in 1...8 { value = value << 8 | UInt64(bytes[offset + i]) }
            guard let intValue = Int(exactly: value) else {
                throw ExchangeFormatError.malformedStructure
            }
            return (majorType, intValue, 9)
        default:
            // 28...31 (including indefinite-length and the break marker) are
            // not supported here.
            throw ExchangeFormatError.malformedStructure
        }
    }

    /// Ensures `index` does not run past the end of the buffer. `index` is a
    /// one-past-the-end position, so it may equal `count`; anything larger means
    /// the input was truncated.
    private static func requireWithinBounds(_ index: Int, in bytes: [UInt8]) throws {
        guard index <= bytes.count else {
            throw ExchangeFormatError.malformedStructure
        }
    }
}
