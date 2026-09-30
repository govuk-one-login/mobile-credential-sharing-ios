@testable import ReaderAuthentication
import CoseVerification
import Crypto
import Foundation
import SwiftCBOR
import Testing

@Suite("Generate COSE_Sign1 ReaderAuth signature")
struct ReaderAuthGeneratorTests {

    // MARK: - AC1: Protected header construction

    @Test("Protected header contains alg ES256 and x5t SHA-256 leaf thumbprint")
    func protectedHeaderStructure() throws {
        let leafDER = Data([0x01, 0x02, 0x03, 0x04])
        let bytes = ReaderAuthGenerator.buildProtectedHeader(leafDER: leafDER)

        let decoded = try #require(try CBOR.decode([UInt8](bytes)))
        guard case let .map(map) = decoded else {
            Issue.record("protected header is not a CBOR map")
            return
        }
        #expect(map.count == 2)
        #expect(map[.unsignedInt(1)] == .negativeInt(6))          // alg ES256 (-7)

        guard case let .array(x5t)? = map[.unsignedInt(34)] else {
            Issue.record("x5t is not an array")
            return
        }
        #expect(x5t.count == 2)
        #expect(x5t[0] == .negativeInt(15))                        // -16 (SHA-256)
        let expected = [UInt8](Data(SHA256.hash(data: leafDER)))
        #expect(x5t[1] == .byteString(expected))
        #expect(expected.count == 32)
    }

    @Test("x5t hash is computed over the exact leaf DER bytes")
    func x5tHashesLeafDER() throws {
        let fixture = try makeReaderAuthSigningFixture()
        let bytes = ReaderAuthGenerator.buildProtectedHeader(leafDER: fixture.leafDER)
        let decoded = try #require(try CBOR.decode([UInt8](bytes)))
        guard case let .map(map) = decoded,
              case let .array(x5t)? = map[.unsignedInt(34)],
              case let .byteString(hash) = x5t[1] else {
            Issue.record("could not extract x5t hash"); return
        }
        #expect(hash == [UInt8](Data(SHA256.hash(data: fixture.leafDER))))
    }

    // MARK: - AC2: Unprotected header construction

    @Test("Two-certificate chain encodes {33: [leafDER, intermediateDER]} leaf-first")
    func multiCertArray() throws {
        let fixture = try makeReaderAuthSigningFixture()
        let bytes = ReaderAuthGenerator.buildUnprotectedHeader(chain: fixture.signingMaterial.certificateChain)
        let decoded = try #require(try CBOR.decode([UInt8](bytes)))
        guard case let .map(map) = decoded, case let .array(chain)? = map[.unsignedInt(33)] else {
            Issue.record("x5chain is not an array"); return
        }
        #expect(chain.count == 2)
        #expect(chain[0] == .byteString([UInt8](fixture.leafDER)))
        #expect(chain[1] == .byteString([UInt8](fixture.intermediateDER)))
    }

    @Test("Single-certificate chain encodes {33: byteString} per RFC 9360 §2")
    func singleCertByteString() throws {
        let leafDER = Data([0xAA, 0xBB])
        let bytes = ReaderAuthGenerator.buildUnprotectedHeader(chain: [leafDER])
        let decoded = try #require(try CBOR.decode([UInt8](bytes)))
        guard case let .map(map) = decoded else { Issue.record("not a map"); return }
        #expect(map[.unsignedInt(33)] == .byteString([UInt8](leafDER)))
    }

    @Test("Leaf hashed for x5t is byte-for-byte the first x5chain entry")
    func x5tMatchesFirstChainEntry() throws {
        let fixture = try makeReaderAuthSigningFixture()
        let unprotected = ReaderAuthGenerator.buildUnprotectedHeader(chain: fixture.signingMaterial.certificateChain)
        let decoded = try #require(try CBOR.decode([UInt8](unprotected)))
        guard case let .map(map) = decoded,
              case let .array(chain)? = map[.unsignedInt(33)],
              case let .byteString(firstEntry) = chain[0] else {
            Issue.record("could not read first chain entry"); return
        }
        #expect(firstEntry == [UInt8](fixture.leafDER))
    }

    // MARK: - AC3: Sig_structure construction

    @Test("Sig_structure has the correct structure")
    func sigStructureShape() throws {
        let protectedHeader = ReaderAuthGenerator.buildProtectedHeader(leafDER: Data([0x01]))
        let bytes = ReaderAuthGenerator.buildSigStructure(
            protectedHeaderBytes: protectedHeader,
            payload: readerAuthSamplePayload
        )
        let decoded = try #require(try CBOR.decode([UInt8](bytes)))
        guard case let .array(elements) = decoded else { Issue.record("not an array"); return }
        #expect(elements.count == 4)
        #expect(elements[0] == .utf8String("Signature1"))
        #expect(elements[1] == .byteString([UInt8](protectedHeader)))   // identical protected bytes
        #expect(elements[2] == .byteString([]))                         // empty external_aad
        #expect(elements[3] == .byteString([UInt8](readerAuthSamplePayload)))
    }

    // MARK: - AC4 & AC5: ES256 signature, COSE_Sign1 assembly, and round-trip

    @Test("Signature field is a 64-byte raw r || s")
    func rawSignatureLength() throws {
        let fixture = try makeReaderAuthSigningFixture()
        let cose = try ReaderAuthGenerator.generate(
            payload: readerAuthSamplePayload,
            signingMaterial: fixture.signingMaterial
        )
        let decoded = try #require(try CBOR.decode([UInt8](cose)))
        guard case let .array(elements) = decoded,
              case let .byteString(sig) = elements[3] else {
            Issue.record("sig not bstr"); return
        }
        #expect(sig.count == 64)
    }

    @Test("Assembled COSE_Sign1 is an untagged 4-element array with null payload")
    func untaggedFourElementNullPayload() throws {
        let fixture = try makeReaderAuthSigningFixture()
        let cose = try ReaderAuthGenerator.generate(
            payload: readerAuthSamplePayload,
            signingMaterial: fixture.signingMaterial
        )

        // Not tagged: first byte is array(4) = 0x84, not a tag.
        #expect(cose.first == 0x84)

        let decoded = try #require(try CBOR.decode([UInt8](cose)))
        guard case let .array(elements) = decoded else { Issue.record("not an array"); return }
        #expect(elements.count == 4)

        if case .byteString = elements[0] {} else { Issue.record("protected not bstr") }
        if case .map = elements[1] {} else { Issue.record("unprotected not map") }
        #expect(elements[2] == .null)                              // detached payload
    }

    @Test("body_protected in COSE equals the Sig_structure protected bytes")
    func protectedBytesConsistent() throws {
        let fixture = try makeReaderAuthSigningFixture()
        let expectedProtected = ReaderAuthGenerator.buildProtectedHeader(leafDER: fixture.leafDER)
        let cose = try ReaderAuthGenerator.generate(
            payload: readerAuthSamplePayload,
            signingMaterial: fixture.signingMaterial
        )
        let decoded = try #require(try CBOR.decode([UInt8](cose)))
        guard case let .array(elements) = decoded,
              case let .byteString(bodyProtected) = elements[0] else {
            Issue.record("could not read body_protected"); return
        }
        #expect(bodyProtected == [UInt8](expectedProtected))
    }

    @Test("Signature verifies over the detached payload with the leaf key (round-trip)")
    func signatureRoundTrips() throws {
        let fixture = try makeReaderAuthSigningFixture()
        let cose = try ReaderAuthGenerator.generate(
            payload: readerAuthSamplePayload,
            signingMaterial: fixture.signingMaterial
        )
        try CoseVerification().verifyDetached(
            coseSign1Bytes: cose,
            detachedPayload: readerAuthSamplePayload,
            publicKey: fixture.leafPublicKey
        )
    }

    @Test("A mutated payload fails verification")
    func mutatedPayloadFails() throws {
        let fixture = try makeReaderAuthSigningFixture()
        let cose = try ReaderAuthGenerator.generate(
            payload: readerAuthSamplePayload,
            signingMaterial: fixture.signingMaterial
        )
        #expect(throws: (any Error).self) {
            try CoseVerification().verifyDetached(
                coseSign1Bytes: cose,
                detachedPayload: Data([0x00, 0x00]),
                publicKey: fixture.leafPublicKey
            )
        }
    }

    // MARK: - AC6: Terminal generation failures

    @Test("Empty chain throws invalidSigningCredential")
    func emptyChain() throws {
        let material = ReaderAuthSigningMaterial(
            certificateChain: [],
            leafPrivateKey: P256.Signing.PrivateKey()
        )
        #expect(throws: ReaderAuthGenerationFailure.invalidSigningCredential) {
            _ = try ReaderAuthGenerator.generate(payload: readerAuthSamplePayload, signingMaterial: material)
        }
    }

    @Test("Malformed leaf DER throws invalidSigningCredential")
    func malformedLeaf() throws {
        let material = ReaderAuthSigningMaterial(
            certificateChain: [Data([0x00, 0x01, 0x02])],
            leafPrivateKey: P256.Signing.PrivateKey()
        )
        #expect(throws: ReaderAuthGenerationFailure.invalidSigningCredential) {
            _ = try ReaderAuthGenerator.generate(payload: readerAuthSamplePayload, signingMaterial: material)
        }
    }

    @Test("Invalid PEM key throws invalidSigningCredential")
    func invalidPEMKey() throws {
        #expect(throws: ReaderAuthGenerationFailure.invalidSigningCredential) {
            _ = try ReaderAuthSigningMaterial(
                certificateChain: [Data([0x01])],
                leafPrivateKeyPEM: "not a valid pem"
            )
        }
    }
}
