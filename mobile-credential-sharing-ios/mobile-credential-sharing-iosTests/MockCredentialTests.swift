import Foundation
import Testing

@testable import mobile_credential_sharing_ios

@Suite("MockCredential Tests")
struct MockCredentialTests {

    // MARK: - AC1: Data Model Defined
    @Test("MockCredential holds id, displayName, rawCredential and privateKey")
    func modelHoldsAllProperties() {
        let rawData = Data([0x01, 0x02])
        let keyData = Data([0xAA, 0xBB])
        let credential = MockCredential(
            id: "test-id",
            displayName: "Test Name",
            rawCredential: rawData,
            privateKey: keyData
        )
        #expect(credential.id == "test-id")
        #expect(credential.displayName == "Test Name")
        #expect(credential.rawCredential == rawData)
        #expect(credential.privateKey == keyData)
    }

    // MARK: - AC2: Mock Data Instantiated
    @Test("Jane Doe credential has correct id")
    func janeDoeId() {
        let credential = makeTestJaneDoe()
        #expect(credential.id == "jane-doe-mock-credential")
    }

    @Test("Jane Doe credential has correct displayName")
    func janeDoeDisplayName() {
        let credential = makeTestJaneDoe()
        #expect(credential.displayName == "Jane Doe")
    }

    @Test("Jane Doe credential rawCredential is not empty")
    func janeDoeRawCredentialNotEmpty() {
        let credential = makeTestJaneDoe()
        #expect(!credential.rawCredential.isEmpty)
    }

    @Test("Jane Doe credential privateKey is 32 bytes")
    func janeDoePrivateKeyLength() {
        let credential = makeTestJaneDoe()
        #expect(credential.privateKey.count == 32)
    }

    @Test("Jane Doe credential privateKey matches expected value")
    func janeDoePrivateKeyValue() {
        let credential = makeTestJaneDoe()
        #expect(credential.privateKey.first == 0x76)
        #expect(credential.privateKey.last == 0x12)
    }

    // MARK: - Helpers
    private func makeTestJaneDoe() -> MockCredential {
        let testBundle = Bundle(for: BundleToken.self)
        return MockCredential.janeDoe(bundle: testBundle)
    }
}

private class BundleToken {}
