import CoseVerification
import Foundation
import Security
import Testing

// MARK: - Mock Verifier (proves protocol is implementable by consumers)

/// A mock conformance to `CoseVerifier` that proves the protocol is publicly
/// adoptable. All methods throw a predetermined failure — no real verification occurs.
struct MockCoseVerifier: CoseVerifier {
    var attachedResult: Result<CoseVerificationResult, CoseVerificationFailure> =
        .failure(.malformedCoseSign1)
    var detachedResult: Result<CoseVerificationResult, CoseVerificationFailure> =
        .failure(.malformedCoseSign1)
    var keyBasedResult: Result<Void, CoseVerificationFailure> =
        .failure(.malformedCoseSign1)

    func verifyAttached(
        coseSign1Bytes: Data,
        trustedRoot: SecCertificate
    ) throws -> CoseVerificationResult {
        switch attachedResult {
        case .success(let result): return result
        case .failure(let error): throw error
        }
    }

    func verifyDetached(
        coseSign1Bytes: Data,
        detachedPayload: Data,
        trustedRoot: SecCertificate
    ) throws -> CoseVerificationResult {
        switch detachedResult {
        case .success(let result): return result
        case .failure(let error): throw error
        }
    }

    func verifyDetached(
        coseSign1Bytes: Data,
        detachedPayload: Data,
        publicKey: SecKey
    ) throws {
        switch keyBasedResult {
        case .success: return
        case .failure(let error): throw error
        }
    }
}

// MARK: - Test Helpers

/// Creates a minimal self-signed certificate for test compilation purposes.
/// This is NOT a cryptographically meaningful certificate — it exists only to
/// satisfy the `SecCertificate` type requirement in compilation probes.
private func createTestCertificate() -> SecCertificate {
    // Valid DER-encoded self-signed X.509 EC P-256 certificate (CN=Test, 365 days)
    // Generated with: openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1
    //   -keyout /dev/null -nodes -out cert.pem -days 365 -subj "/CN=Test"
    let derBase64 =
        "MIIBczCCARmgAwIBAgIUWl8BgTTkJid7Z0dGO73JZA0NO+AwCgYIKoZIzj0EAwIw" +
        "DzENMAsGA1UEAwwEVGVzdDAeFw0yNjA4MjAxNDM0NTRaFw0yNzA4MjAxNDM0NTRa" +
        "MA8xDTALBgNVBAMMBFRlc3QwWTATBgcqhkjOPQIBBggqhkjOPQMBBwNCAAQ6F3Ej" +
        "AbeQFpr4mQcnL1gs0qa/6daNtd82eP/gLphdoBsrYE+WXy4sP0WfKqWFwIrOFI2f" +
        "UMgP/fAIYMnad8kFo1MwUTAdBgNVHQ4EFgQUYZp7dpBZCGIoUb99qrxp/o9K7+Mw" +
        "HwYDVR0jBBgwFoAUYZp7dpBZCGIoUb99qrxp/o9K7+MwDwYDVR0TAQH/BAUwAwEB" +
        "/zAKBggqhkjOPQQDAgNIADBFAiBXKGO7oizQofRlnHlXhPWHjGNmEH9uIGqxkGLU" +
        "b7eGrgIhAMc4j4nqE6XLxfwx0eZdvGXhxiV1W212G7qm3KY1H7du"

    guard let derData = Data(base64Encoded: derBase64),
          let certificate = SecCertificateCreateWithData(nil, derData as CFData) else {
        fatalError("Failed to create test certificate — DER data is invalid")
    }
    return certificate
}

/// Creates a minimal EC public key for test compilation purposes.
private func createTestPublicKey() -> SecKey {
    let attributes: [String: Any] = [
        kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
        kSecAttrKeySizeInBits as String: 256
    ]

    var error: Unmanaged<CFError>?
    guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error),
          let publicKey = SecKeyCopyPublicKey(privateKey) else {
        fatalError("Failed to create test EC key pair: \(error!.takeRetainedValue())")
    }
    return publicKey
}

// MARK: - Contract Test Suites

@Suite("CoseVerificationFailure Contract Tests")
struct CoseVerificationFailureContractTests {
    @Test("All failure cases are exhaustively matchable")
    func exhaustiveSwitch() {
        let failures: [CoseVerificationFailure] = [
            .invalidSignature,
            .untrustedCertificate,
            .unsupportedAlgorithm,
            .malformedCoseSign1,
            .missingX5Chain,
            .certificateProfileViolation(reason: "KeyUsage: digitalSignature not present")
        ]

        for failure in failures {
            switch failure {
            case .invalidSignature:
                break
            case .untrustedCertificate:
                break
            case .unsupportedAlgorithm:
                break
            case .malformedCoseSign1:
                break
            case .missingX5Chain:
                break
            case .certificateProfileViolation(let reason):
                #expect(!reason.isEmpty)
            }
        }
    }

    @Test("Equatable conformance")
    func equatable() {
        #expect(CoseVerificationFailure.invalidSignature == .invalidSignature)
        #expect(CoseVerificationFailure.invalidSignature != .untrustedCertificate)
        #expect(
            CoseVerificationFailure.certificateProfileViolation(reason: "A")
            != .certificateProfileViolation(reason: "B")
        )
        #expect(
            CoseVerificationFailure.certificateProfileViolation(reason: "same")
            == .certificateProfileViolation(reason: "same")
        )
    }

    @Test("Conforms to Error protocol")
    func errorConformance() {
        let failure: any Error = CoseVerificationFailure.invalidSignature
        #expect(failure is CoseVerificationFailure)
    }

    @Test("Conforms to Sendable")
    func sendableConformance() {
        let _: any Sendable = CoseVerificationFailure.invalidSignature
        let _: any Sendable = CoseVerificationFailure.certificateProfileViolation(reason: "test")
    }
}

@Suite("CoseVerifier Protocol Contract Tests")
struct CoseVerifierContractTests {
    @Test("Protocol is adoptable by consumers")
    func protocolAdoption() {
        let verifier: any CoseVerifier = MockCoseVerifier()
        _ = verifier
    }

    @Test("verifyAttached throws expected failure")
    func verifyAttachedThrows() {
        let verifier = MockCoseVerifier(
            attachedResult: .failure(.missingX5Chain)
        )
        let certificate = createTestCertificate()

        #expect(throws: CoseVerificationFailure.missingX5Chain) {
            try verifier.verifyAttached(
                coseSign1Bytes: Data(),
                trustedRoot: certificate
            )
        }
    }

    @Test("verifyDetached (chain-based) throws expected failure")
    func verifyDetachedChainBasedThrows() {
        let verifier = MockCoseVerifier(
            detachedResult: .failure(.untrustedCertificate)
        )
        let certificate = createTestCertificate()

        #expect(throws: CoseVerificationFailure.untrustedCertificate) {
            try verifier.verifyDetached(
                coseSign1Bytes: Data(),
                detachedPayload: Data(),
                trustedRoot: certificate
            )
        }
    }

    @Test("verifyDetached (key-based) throws expected failure")
    func verifyDetachedKeyBasedThrows() {
        let verifier = MockCoseVerifier(
            keyBasedResult: .failure(.invalidSignature)
        )
        let key = createTestPublicKey()

        #expect(throws: CoseVerificationFailure.invalidSignature) {
            try verifier.verifyDetached(
                coseSign1Bytes: Data(),
                detachedPayload: Data(),
                publicKey: key
            )
        }
    }

    @Test("verifyDetached (key-based) succeeds silently")
    func verifyDetachedKeyBasedSucceeds() throws {
        let verifier = MockCoseVerifier(
            keyBasedResult: .success(())
        )
        let key = createTestPublicKey()

        try verifier.verifyDetached(
            coseSign1Bytes: Data(),
            detachedPayload: Data(),
            publicKey: key
        )
    }
}
