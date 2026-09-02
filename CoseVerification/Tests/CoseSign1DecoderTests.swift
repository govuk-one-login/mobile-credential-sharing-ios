@testable import CoseVerification
import Foundation
import Testing

// swiftlint:disable file_length

// MARK: - AC1: A valid COSE_Sign1 exposes its components for verification

@Suite("AC1: Valid COSE_Sign1 exposes components")
struct AC1Tests {
    @Test("Valid attached COSE_Sign1 exposes all components")
    func validAttachedExposesComponents() throws {
        let data = makeValidAttachedCoseSign1()

        let decoded = try CoseSign1Decoder.decode(data)

        #expect(decoded.protectedHeaderBytes == Data([0xA1, 0x01, 0x26]))
        #expect(decoded.protectedHeader[.algorithmLabel] == .int(-7))
        #expect(decoded.unprotectedHeader.entries.isEmpty)
        #expect(decoded.payload == Data([0x01, 0x02, 0x03]))
        #expect(decoded.signature == Data(repeating: 0xAA, count: 64))
    }

    @Test("Original protected-header bytes remain unchanged")
    func protectedHeaderBytesPreserved() throws {
        // Use a non-minimal encoding to prove we preserve the original bytes
        // Protected header: {1: -7} but encoded with 2-byte map header (B9 00 01 instead of A1)
        // B9 = map with 2-byte length, 00 01 = 1 pair, then 01 = key 1, 26 = value -7
        let nonCanonicalProtectedHeader: [UInt8] = [0xB9, 0x00, 0x01, 0x01, 0x26]
        let data = makeValidAttachedCoseSign1(protectedHeaderBytes: nonCanonicalProtectedHeader)

        let decoded = try CoseSign1Decoder.decode(data)

        // The preserved bytes must be the exact input, not re-encoded
        #expect(decoded.protectedHeaderBytes == Data(nonCanonicalProtectedHeader))
    }

    @Test("Valid detached COSE_Sign1 exposes nil payload")
    func validDetachedExposesNilPayload() throws {
        let data = makeValidDetachedCoseSign1()

        let decoded = try CoseSign1Decoder.decode(data)

        #expect(decoded.payload == nil)
        #expect(decoded.signature == Data(repeating: 0xAA, count: 64))
    }
}

// MARK: - AC2: A valid attached COSE_Sign1 preserves its signed bytes

@Suite("AC2: Attached COSE_Sign1 preserves signed bytes")
struct AC2Tests {
    @Test("Attached payload bytes are preserved without re-encoding")
    func attachedPayloadBytesPreserved() throws {
        let originalPayload: [UInt8] = [0xDE, 0xAD, 0xBE, 0xEF, 0xCA, 0xFE]
        let data = makeValidAttachedCoseSign1(payload: originalPayload)

        let decoded = try CoseSign1Decoder.decode(data)

        #expect(decoded.payload == Data(originalPayload))
    }

    @Test("Protected header and payload available without re-encoding")
    func componentsAvailableForVerification() throws {
        let payload: [UInt8] = [0x01, 0x02, 0x03, 0x04, 0x05]
        let data = makeValidAttachedCoseSign1(payload: payload)

        let decoded = try CoseSign1Decoder.decode(data)
        let effectivePayload = try PayloadModeValidator.payload(
            for: .attached,
            from: decoded
        )

        #expect(effectivePayload == Data(payload))
        #expect(decoded.protectedHeaderBytes == Data([0xA1, 0x01, 0x26]))
    }
}

// MARK: - AC3: Invalid COSE_Sign1 structures are rejected

@Suite("AC3: Invalid structures rejected as malformedCoseSign1")
struct AC3Tests {
    @Test("Bytes that are not valid CBOR")
    func invalidCbor() {
        let data = Data([0xFF, 0xFF, 0xFF])

        #expect(throws: CoseVerificationFailure.malformedCoseSign1) {
            try CoseSign1Decoder.decode(data)
        }
    }

    @Test("A tagged COSE_Sign1 value")
    func taggedValue() {
        // CBOR tag 18 (COSE_Sign1) wrapping a valid array
        // D2 = tag(18), then the valid 4-element array
        let inner = makeValidAttachedCoseSign1()
       
        // Tag 18 = 0xD2 followed by the array
        let data = Data([0xD2]) + inner

        #expect(throws: CoseVerificationFailure.malformedCoseSign1) {
            try CoseSign1Decoder.decode(data)
        }
    }

    @Test("A CBOR value that is not an array")
    func notAnArray() {
        // CBOR map: A0 (empty map)
        let data = Data([0xA0])

        #expect(throws: CoseVerificationFailure.malformedCoseSign1) {
            try CoseSign1Decoder.decode(data)
        }
    }

    @Test("A non-canonical array header encoding is rejected")
    func nonCanonicalArrayHeader() {
        // A 4-element array encoded with a 2-byte header (0x98 0x04) instead of
        // the canonical single-byte form (0x84). SwiftCBOR would still decode this
        // fine, but our byte-offset logic assumes 0x84 so we reject it early.
        var inner = [UInt8](makeValidAttachedCoseSign1())
        // Replace the canonical 0x84 header with 0x98 0x04 (array with 1-byte length)
        inner[0] = 0x98
        inner.insert(0x04, at: 1)
        let data = Data(inner)

        #expect(throws: CoseVerificationFailure.malformedCoseSign1) {
            try CoseSign1Decoder.decode(data)
        }
    }

    @Test("An array containing fewer than four elements")
    func fewerThanFourElements() {
        // 3-element array: 83 followed by 3 items (byte strings)
        let data = Data([0x83, 0x40, 0xA0, 0x40])

        #expect(throws: CoseVerificationFailure.malformedCoseSign1) {
            try CoseSign1Decoder.decode(data)
        }
    }

    @Test("An array containing more than four elements")
    func moreThanFourElements() {
        // 5-element array: 85 followed by 5 items
        let data = Data([0x85, 0x43, 0xA1, 0x01, 0x26, 0xA0, 0x43, 0x01, 0x02, 0x03, 0x41, 0xAA, 0x40])

        #expect(throws: CoseVerificationFailure.malformedCoseSign1) {
            try CoseSign1Decoder.decode(data)
        }
    }

    @Test("A protected header that is not a byte string")
    func protectedHeaderNotByteString() {
        // 4-element array where element 0 is a text string instead of byte string
        // 84 = array(4), 61 61 = text("a"), A0 = empty map, F6 = null, 40 = empty bstr
        let data = Data([0x84, 0x61, 0x61, 0xA0, 0xF6, 0x40])

        #expect(throws: CoseVerificationFailure.malformedCoseSign1) {
            try CoseSign1Decoder.decode(data)
        }
    }

    @Test("Protected-header bytes that do not decode to a map")
    func protectedHeaderBytesNotMap() {
        // Protected header byte string contains a CBOR array instead of a map
        // 81 00 = array [0]
        let data = makeValidAttachedCoseSign1(protectedHeaderBytes: [0x81, 0x00])

        #expect(throws: CoseVerificationFailure.malformedCoseSign1) {
            try CoseSign1Decoder.decode(data)
        }
    }

    @Test("An unprotected header that is not a map")
    func unprotectedHeaderNotMap() {
        // Unprotected header is a byte string (40 = empty bstr) instead of a map
        let data = makeValidAttachedCoseSign1(unprotectedHeader: [0x40])

        #expect(throws: CoseVerificationFailure.malformedCoseSign1) {
            try CoseSign1Decoder.decode(data)
        }
    }

    @Test("A payload that is neither a byte string nor null")
    func payloadNotByteStringOrNull() {
        // Build manually: array(4) with payload as unsigned int 42 (18 2A)
        let protHeaderBstr = cborByteString([0xA1, 0x01, 0x26])
        let sigBstr = cborByteString([UInt8](repeating: 0xAA, count: 64))

        var bytes: [UInt8] = [0x84]
        bytes.append(contentsOf: protHeaderBstr)
        bytes.append(0xA0) // unprotected header: empty map
        bytes.append(contentsOf: [0x18, 0x2A]) // unsigned int 42 (not bstr or null)
        bytes.append(contentsOf: sigBstr)

        let data = Data(bytes)

        #expect(throws: CoseVerificationFailure.malformedCoseSign1) {
            try CoseSign1Decoder.decode(data)
        }
    }

    @Test("A signature that is not a byte string")
    func signatureNotByteString() {
        // Build manually: array(4) with signature as unsigned int 0
        let protHeaderBstr = cborByteString([0xA1, 0x01, 0x26])
        let payloadBstr = cborByteString([0x01, 0x02, 0x03])

        var bytes: [UInt8] = [0x84]
        bytes.append(contentsOf: protHeaderBstr)
        bytes.append(0xA0) // unprotected header
        bytes.append(contentsOf: payloadBstr)
        bytes.append(0x00) // unsigned int 0 (not a byte string)

        let data = Data(bytes)

        #expect(throws: CoseVerificationFailure.malformedCoseSign1) {
            try CoseSign1Decoder.decode(data)
        }
    }

    @Test("A duplicate label in the protected header map")
    func duplicateLabelInProtectedHeader() {
        // Manually craft a CBOR map with 2 pairs both using key 1:
        // A2 = map(2 pairs), 01 = key 1, 26 = -7, 01 = key 1 again, 26 = -7
        let duplicateProtectedHeader: [UInt8] = [0xA2, 0x01, 0x26, 0x01, 0x26]
        let data = makeValidAttachedCoseSign1(protectedHeaderBytes: duplicateProtectedHeader)

        #expect(throws: CoseVerificationFailure.malformedCoseSign1) {
            try CoseSign1Decoder.decode(data)
        }
    }

    @Test("A duplicate label in the unprotected header map")
    func duplicateLabelInUnprotectedHeader() {
        // Manually craft unprotected header with duplicate key 2:
        // A2 = map(2 pairs), 02 = key 2, 40 = empty bstr, 02 = key 2 again, 40 = empty bstr
        let duplicateUnprotectedHeader: [UInt8] = [0xA2, 0x02, 0x40, 0x02, 0x40]
        let data = makeValidAttachedCoseSign1(unprotectedHeader: duplicateUnprotectedHeader)

        #expect(throws: CoseVerificationFailure.malformedCoseSign1) {
            try CoseSign1Decoder.decode(data)
        }
    }

    @Test("The same label present in both header maps")
    func sharedLabelBetweenHeaders() {
        // Protected header has label 1 (alg): {1: -7}
        // Unprotected header also has label 1: {1: 0}
        // A1 01 00 = map(1) { 1: 0 }
        let unprotectedWithAlg: [UInt8] = [0xA1, 0x01, 0x00]
        let data = makeValidAttachedCoseSign1(unprotectedHeader: unprotectedWithAlg)

        #expect(throws: CoseVerificationFailure.malformedCoseSign1) {
            try CoseSign1Decoder.decode(data)
        }
    }
}

// MARK: - AC4: The algorithm must be declared in the protected header

@Suite("AC4: Algorithm must be in protected header")
struct AC4Tests {
    @Test("No alg label in protected header")
    func noAlgInProtectedHeader() {
        // Protected header with only label 4 (kid): {4: h''}
        // A1 04 40 = map(1) { 4: empty bstr }
        let protHeaderNoAlg: [UInt8] = [0xA1, 0x04, 0x40]
        let data = makeValidAttachedCoseSign1(protectedHeaderBytes: protHeaderNoAlg)

        #expect(throws: CoseVerificationFailure.unsupportedAlgorithm) {
            try CoseSign1Decoder.decode(data)
        }
    }

    @Test("Empty protected header")
    func emptyProtectedHeader() {
        // Empty map: A0
        let data = makeValidAttachedCoseSign1(protectedHeaderBytes: [0xA0])

        #expect(throws: CoseVerificationFailure.unsupportedAlgorithm) {
            try CoseSign1Decoder.decode(data)
        }
    }

    @Test("Alg in unprotected header only is rejected")
    func algInUnprotectedHeaderOnly() {
        // Protected header has no alg — just label 4 (kid): {4: h''}
        // A1 04 40 = map(1) { 4: empty bstr }
        let protHeaderNoAlg: [UInt8] = [0xA1, 0x04, 0x40]
        // Unprotected header has alg = -7 (ES256): {1: -7}
        // A1 01 26 = map(1) { 1: -7 }
        let unprotHeaderWithAlg: [UInt8] = [0xA1, 0x01, 0x26]
        let data = makeValidAttachedCoseSign1(
            protectedHeaderBytes: protHeaderNoAlg,
            unprotectedHeader: unprotHeaderWithAlg
        )

        #expect(throws: CoseVerificationFailure.unsupportedAlgorithm) {
            try CoseSign1Decoder.decode(data)
        }
    }
}

// MARK: - AC5: An algorithm other than ES256 is rejected

@Suite("AC5: Non-ES256 algorithm rejected")
struct AC5Tests {
    @Test("ES384 (alg = -35) is rejected")
    func es384Rejected() {
        // {1: -35} → A1 01 38 22
        // 38 22 = negative int, additional info 24 (1-byte follows), value 34 → -1-34 = -35
        let protHeaderES384: [UInt8] = [0xA1, 0x01, 0x38, 0x22]
        let data = makeValidAttachedCoseSign1(protectedHeaderBytes: protHeaderES384)

        #expect(throws: CoseVerificationFailure.unsupportedAlgorithm) {
            try CoseSign1Decoder.decode(data)
        }
    }

    @Test("ES512 (alg = -36) is rejected")
    func es512Rejected() {
        // {1: -36} → A1 01 38 23
        let protHeaderES512: [UInt8] = [0xA1, 0x01, 0x38, 0x23]
        let data = makeValidAttachedCoseSign1(protectedHeaderBytes: protHeaderES512)

        #expect(throws: CoseVerificationFailure.unsupportedAlgorithm) {
            try CoseSign1Decoder.decode(data)
        }
    }

    @Test("Algorithm as a positive integer is rejected")
    func positiveAlgRejected() {
        // {1: 7} → A1 01 07
        let protHeaderPositive: [UInt8] = [0xA1, 0x01, 0x07]
        let data = makeValidAttachedCoseSign1(protectedHeaderBytes: protHeaderPositive)

        #expect(throws: CoseVerificationFailure.unsupportedAlgorithm) {
            try CoseSign1Decoder.decode(data)
        }
    }

    @Test("Algorithm as a text string is rejected")
    func textAlgRejected() {
        // {1: "ES256"} → A1 01 65 4553323536
        let protHeaderText: [UInt8] = [0xA1, 0x01, 0x65, 0x45, 0x53, 0x32, 0x35, 0x36]
        let data = makeValidAttachedCoseSign1(protectedHeaderBytes: protHeaderText)

        #expect(throws: CoseVerificationFailure.unsupportedAlgorithm) {
            try CoseSign1Decoder.decode(data)
        }
    }
}

// MARK: - AC6: Attached verification rejects a detached COSE_Sign1

@Suite("AC6: Attached mode rejects null payload")
struct AC6Tests {
    @Test("Attached mode with null payload throws malformedCoseSign1")
    func attachedModeRejectsNullPayload() throws {
        let data = makeValidDetachedCoseSign1()
        let decoded = try CoseSign1Decoder.decode(data)

        #expect(throws: CoseVerificationFailure.malformedCoseSign1) {
            try PayloadModeValidator.payload(
                for: .attached,
                from: decoded
            )
        }
    }
}

// MARK: - AC7: Detached verification rejects an attached COSE_Sign1

@Suite("AC7: Detached mode rejects non-null payload")
struct AC7Tests {
    @Test("Detached mode with attached payload throws malformedCoseSign1")
    func detachedModeRejectsAttachedPayload() throws {
        let data = makeValidAttachedCoseSign1()
        let decoded = try CoseSign1Decoder.decode(data)

        let externalPayload = Data([0xFF, 0xFE, 0xFD])
        #expect(throws: CoseVerificationFailure.malformedCoseSign1) {
            try PayloadModeValidator.payload(
                for: .detached(externalPayload: externalPayload),
                from: decoded
            )
        }
    }
}

// MARK: - Byte Preservation Proofs

@Suite("Byte preservation proofs")
struct BytePreservationTests {
    @Test("Protected header bytes survive decode unchanged")
    func protectedHeaderRoundTrip() throws {
        // Encode {1: -7, 4: h'CAFE'} in a specific order
        // A2 = map(2), 01 = 1, 26 = -7, 04 = 4, 42 CA FE = bstr h'CAFE'
        let specificHeader: [UInt8] = [0xA2, 0x01, 0x26, 0x04, 0x42, 0xCA, 0xFE]
        let data = makeValidAttachedCoseSign1(protectedHeaderBytes: specificHeader)

        let decoded = try CoseSign1Decoder.decode(data)

        #expect(decoded.protectedHeaderBytes == Data(specificHeader))
    }

    @Test("Attached payload bytes survive decode unchanged")
    func attachedPayloadRoundTrip() throws {
        let originalPayload: [UInt8] = [0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77]
        let data = makeValidAttachedCoseSign1(payload: originalPayload)

        let decoded = try CoseSign1Decoder.decode(data)

        #expect(decoded.payload == Data(originalPayload))
    }

    @Test("Detached external payload passes through unchanged")
    func detachedPayloadPassthrough() throws {
        let data = makeValidDetachedCoseSign1()
        let decoded = try CoseSign1Decoder.decode(data)

        let externalPayload = Data([0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF])
        let result = try PayloadModeValidator.payload(
            for: .detached(externalPayload: externalPayload),
            from: decoded
        )

        #expect(result == externalPayload)
    }

    @Test("Signature bytes survive decode unchanged")
    func signatureBytesPreserved() throws {
        let originalSignature = [UInt8](repeating: 0x42, count: 64)
        let data = makeValidAttachedCoseSign1(signature: originalSignature)

        let decoded = try CoseSign1Decoder.decode(data)

        #expect(decoded.signature == Data(originalSignature))
    }
}

// swiftlint:enable file_length
