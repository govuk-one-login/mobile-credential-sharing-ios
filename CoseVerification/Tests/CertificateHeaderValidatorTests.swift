@testable import CoseVerification
import Foundation
import SwiftCBOR
import Testing

@Suite("Certificate header validation")
struct CertificateHeaderValidatorTests {

    // MARK: - AC1: A valid certificate-header profile exposes the thumbprint-bound signing leaf

    @Test("Single-DER x5chain with x5bag in the protected header exposes the leaf")
    func singleDerChainWithProtectedBag() throws {
        let cose = makeCoseSign1(
            protected: [
                (x5tLabel(), x5tValue(hash: CertificateFixtures.leafSHA256)),
                (x5bagLabel(), x5chainSingle(CertificateFixtures.intermediateDER))
            ],
            unprotected: [
                (x5chainLabel(), x5chainSingle(CertificateFixtures.leafDER))
            ]
        )

        let material = try CertificateHeaderValidator.validate(cose)

        #expect(material.certificateChain.first == CertificateFixtures.leafDER)
        #expect(material.certificateChain == [CertificateFixtures.leafDER])
        // x5bag bytes must not appear as chain material.
        #expect(!material.certificateChain.contains(CertificateFixtures.intermediateDER))
    }

    @Test("Array x5chain with x5bag in the unprotected header preserves supplied order")
    func arrayChainWithUnprotectedBag() throws {
        let cose = makeCoseSign1(
            protected: [
                (x5tLabel(), x5tValue(hash: CertificateFixtures.leafSHA256))
            ],
            unprotected: [
                (x5chainLabel(), x5chainArray([CertificateFixtures.leafDER, CertificateFixtures.intermediateDER])),
                (x5bagLabel(), x5chainSingle(Data([0xEE, 0xEE])))
            ]
        )

        let material = try CertificateHeaderValidator.validate(cose)

        #expect(material.certificateChain.first == CertificateFixtures.leafDER)
        #expect(material.certificateChain == [CertificateFixtures.leafDER, CertificateFixtures.intermediateDER])
    }

    // MARK: - AC2: Chain-based verification rejects a missing x5chain

    @Test("No x5chain in either header fails with missingX5Chain")
    func missingChain() {
        let cose = makeCoseSign1(
            protected: [(x5tLabel(), x5tValue(hash: CertificateFixtures.leafSHA256))]
        )

        #expect(throws: CoseVerificationFailure.missingX5Chain) {
            try CertificateHeaderValidator.validate(cose)
        }
    }

    @Test("x5bag present without x5chain still fails with missingX5Chain")
    func bagWithoutChain() {
        let cose = makeCoseSign1(
            protected: [(x5tLabel(), x5tValue(hash: CertificateFixtures.leafSHA256))],
            unprotected: [(x5bagLabel(), x5chainSingle(CertificateFixtures.intermediateDER))]
        )

        #expect(throws: CoseVerificationFailure.missingX5Chain) {
            try CertificateHeaderValidator.validate(cose)
        }
    }

    // MARK: - AC3: A protected x5chain is rejected

    @Test("x5chain in the protected header fails with malformedCoseSign1")
    func protectedChainRejected() {
        let cose = makeCoseSign1(
            protected: [
                (x5tLabel(), x5tValue(hash: CertificateFixtures.leafSHA256)),
                (x5chainLabel(), x5chainSingle(CertificateFixtures.leafDER))
            ]
        )

        #expect(throws: CoseVerificationFailure.malformedCoseSign1) {
            try CertificateHeaderValidator.validate(cose)
        }
    }

    // MARK: - AC4: An empty or malformed unprotected x5chain is rejected

    @Test("An empty x5chain array fails with malformedCoseSign1")
    func emptyArrayRejected() {
        let cose = makeCoseSign1(
            protected: [(x5tLabel(), x5tValue(hash: CertificateFixtures.leafSHA256))],
            unprotected: [(x5chainLabel(), .array([]))]
        )

        #expect(throws: CoseVerificationFailure.malformedCoseSign1) {
            try CertificateHeaderValidator.validate(cose)
        }
    }

    @Test("An x5chain that is neither a byte string nor an array fails with malformedCoseSign1")
    func nonCertificateValueRejected() {
        let cose = makeCoseSign1(
            protected: [(x5tLabel(), x5tValue(hash: CertificateFixtures.leafSHA256))],
            unprotected: [(x5chainLabel(), .unsignedInt(42))]
        )

        #expect(throws: CoseVerificationFailure.malformedCoseSign1) {
            try CertificateHeaderValidator.validate(cose)
        }
    }

    @Test("An x5chain array containing a non-byte-string element fails with malformedCoseSign1")
    func arrayWithNonByteStringRejected() {
        let cose = makeCoseSign1(
            protected: [(x5tLabel(), x5tValue(hash: CertificateFixtures.leafSHA256))],
            unprotected: [(x5chainLabel(), .array([.byteString([UInt8](CertificateFixtures.leafDER)), .unsignedInt(1)]))]
        )

        #expect(throws: CoseVerificationFailure.malformedCoseSign1) {
            try CertificateHeaderValidator.validate(cose)
        }
    }

    // MARK: - AC5: Missing or unprotected x5t is rejected

    @Test("Absent x5t fails with malformedCoseSign1")
    func absentThumbprint() {
        let cose = makeCoseSign1(
            unprotected: [(x5chainLabel(), x5chainSingle(CertificateFixtures.leafDER))]
        )

        #expect(throws: CoseVerificationFailure.malformedCoseSign1) {
            try CertificateHeaderValidator.validate(cose)
        }
    }

    @Test("x5t in the unprotected header fails with malformedCoseSign1")
    func unprotectedThumbprint() {
        let cose = makeCoseSign1(
            unprotected: [
                (x5chainLabel(), x5chainSingle(CertificateFixtures.leafDER)),
                (x5tLabel(), x5tValue(hash: CertificateFixtures.leafSHA256))
            ]
        )

        #expect(throws: CoseVerificationFailure.malformedCoseSign1) {
            try CertificateHeaderValidator.validate(cose)
        }
    }

    // MARK: - AC6: A malformed protected x5t is rejected

    @Test("x5t that is not a two-element array fails with malformedCoseSign1")
    func notTwoElementArray() {
        let cose = makeCoseSign1(
            protected: [(x5tLabel(), .array([sha256AlgorithmCBOR()]))],
            unprotected: [(x5chainLabel(), x5chainSingle(CertificateFixtures.leafDER))]
        )

        #expect(throws: CoseVerificationFailure.malformedCoseSign1) {
            try CertificateHeaderValidator.validate(cose)
        }
    }

    @Test("x5t first element that is not a COSE algorithm identifier fails with malformedCoseSign1")
    func firstElementNotAlgorithm() {
        let cose = makeCoseSign1(
            protected: [(x5tLabel(), .array([.utf8String("SHA-256"), .byteString([UInt8](CertificateFixtures.leafSHA256))]))],
            unprotected: [(x5chainLabel(), x5chainSingle(CertificateFixtures.leafDER))]
        )

        #expect(throws: CoseVerificationFailure.malformedCoseSign1) {
            try CertificateHeaderValidator.validate(cose)
        }
    }

    @Test("x5t second element that is not a byte string fails with malformedCoseSign1")
    func secondElementNotByteString() {
        let cose = makeCoseSign1(
            protected: [(x5tLabel(), .array([sha256AlgorithmCBOR(), .unsignedInt(0)]))],
            unprotected: [(x5chainLabel(), x5chainSingle(CertificateFixtures.leafDER))]
        )

        #expect(throws: CoseVerificationFailure.malformedCoseSign1) {
            try CertificateHeaderValidator.validate(cose)
        }
    }

    @Test("SHA-256 x5t with a hash that is not 32 bytes fails with malformedCoseSign1")
    func wrongLengthHash() {
        let cose = makeCoseSign1(
            protected: [(x5tLabel(), x5tValue(hash: Data(repeating: 0x00, count: 16)))],
            unprotected: [(x5chainLabel(), x5chainSingle(CertificateFixtures.leafDER))]
        )

        #expect(throws: CoseVerificationFailure.malformedCoseSign1) {
            try CertificateHeaderValidator.validate(cose)
        }
    }

    // MARK: - AC7: An x5t hash algorithm other than SHA-256 is rejected

    @Test("A SHA-384 (-43) x5t algorithm fails with unsupportedAlgorithm")
    func sha384Rejected() {
        // COSE identifier -43 encodes as .negativeInt(42).
        let cose = makeCoseSign1(
            protected: [(x5tLabel(), x5tValue(algorithm: .negativeInt(42), hash: CertificateFixtures.leafSHA256))],
            unprotected: [(x5chainLabel(), x5chainSingle(CertificateFixtures.leafDER))]
        )

        #expect(throws: CoseVerificationFailure.unsupportedAlgorithm) {
            try CertificateHeaderValidator.validate(cose)
        }
    }

    // MARK: - AC8: A mismatched x5t rejects the selected leaf certificate

    @Test("A 32-byte x5t that does not match the leaf digest fails with invalidSignature")
    func mismatchedThumbprint() {
        let cose = makeCoseSign1(
            protected: [(x5tLabel(), x5tValue(hash: Data(repeating: 0x00, count: 32)))],
            unprotected: [(x5chainLabel(), x5chainSingle(CertificateFixtures.leafDER))]
        )

        #expect(throws: CoseVerificationFailure.invalidSignature) {
            try CertificateHeaderValidator.validate(cose)
        }
    }
}
