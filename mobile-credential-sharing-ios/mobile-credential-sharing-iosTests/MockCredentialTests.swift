import Foundation
import Testing

@testable import mobile_credential_sharing_ios

@MainActor
@Suite("MockCredential Tests")
struct MockCredentialTests {

    // MARK: Data Model Defined
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

    @Test("MockCredential defaults signingStrategy to success")
    func defaultSigningStrategy() {
        let credential = MockCredential(
            id: "id",
            displayName: "Name",
            rawCredential: Data(),
            privateKey: Data()
        )
        #expect(credential.signingStrategy == .success)
    }

    @Test("MockCredential accepts explicit signingStrategy")
    func explicitSigningStrategy() {
        let credential = MockCredential(
            id: "id",
            displayName: "Name",
            rawCredential: Data(),
            privateKey: Data(),
            signingStrategy: .alwaysFail
        )
        #expect(credential.signingStrategy == .alwaysFail)
    }

    // MARK: Mock Data Instantiated
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

    // MARK: Signing Failure Credential
    @Test("Signing failure credential has correct displayName")
    func signingFailureDisplayName() {
        let credential = makeTestJaneDoeSigningFailure()
        #expect(credential.displayName == "Jane Doe (Signing Failure)")
    }

    @Test("Signing failure credential uses alwaysFail strategy")
    func signingFailureStrategy() {
        let credential = makeTestJaneDoeSigningFailure()
        #expect(credential.signingStrategy == .alwaysFail)
    }

    @Test("Signing failure credential reuses Jane Doe credential data")
    func signingFailureReusesBaseData() {
        let base = makeTestJaneDoe()
        let failure = makeTestJaneDoeSigningFailure()
        #expect(failure.id == base.id)
        #expect(failure.rawCredential == base.rawCredential)
        #expect(failure.privateKey == base.privateKey)
    }

    // MARK: Authentication Cancelled Once Credential
    @Test("Auth cancelled once credential has correct displayName")
    func authCancelledOnceDisplayName() {
        let credential = makeTestJaneDoeAuthCancelledOnce()
        #expect(credential.displayName == "Jane Doe (Authentication Cancelled Once)")
    }

    @Test("Auth cancelled once credential uses failOnceThenSucceed strategy")
    func authCancelledOnceStrategy() {
        let credential = makeTestJaneDoeAuthCancelledOnce()
        #expect(credential.signingStrategy == .failOnceThenSucceed)
    }

    @Test("Auth cancelled once credential reuses Jane Doe credential data")
    func authCancelledOnceReusesBaseData() {
        let base = makeTestJaneDoe()
        let authCancelled = makeTestJaneDoeAuthCancelledOnce()
        #expect(authCancelled.id == base.id)
        #expect(authCancelled.rawCredential == base.rawCredential)
        #expect(authCancelled.privateKey == base.privateKey)
    }

    // MARK: - AC5: allMocks
    @Test("allMocks contains all five credential entries")
    func allMocksCount() {
        #expect(MockCredential.allMocks.count == 5)
    }

    @Test("allMocks display names include signing failure and auth cancelled")
    func allMocksContainsNewCredentials() {
        let names = MockCredential.allMocks.map(\.displayName)
        #expect(names.contains("Jane Doe (Signing Failure)"))
        #expect(names.contains("Jane Doe (Authentication Cancelled Once)"))
    }

    @Test("allMocks includes the absent x5t credential")
    func allMocksContainsAbsentX5t() {
        let names = MockCredential.allMocks.map(\.displayName)
        #expect(names.contains("Jane Doe (absent x5t)"))
    }

    // MARK: - AC4: Absent x5t Credential
    @Test("Absent x5t credential has correct displayName")
    func absentX5tDisplayName() {
        let credential = makeTestJaneDoeAbsentX5t()
        #expect(credential.displayName == "Jane Doe (absent x5t)")
    }

    @Test("Absent x5t credential has its own id")
    func absentX5tId() {
        let credential = makeTestJaneDoeAbsentX5t()
        #expect(credential.id == "jane-doe-absent-x5t")
    }

    @Test("Absent x5t credential rawCredential is not empty")
    func absentX5tRawCredentialNotEmpty() {
        let credential = makeTestJaneDoeAbsentX5t()
        #expect(!credential.rawCredential.isEmpty)
    }

    @Test("Absent x5t credential privateKey is 32 bytes")
    func absentX5tPrivateKeyLength() {
        let credential = makeTestJaneDoeAbsentX5t()
        #expect(credential.privateKey.count == 32)
    }

    @Test("Absent x5t credential defaults to success signing strategy")
    func absentX5tSigningStrategy() {
        let credential = makeTestJaneDoeAbsentX5t()
        #expect(credential.signingStrategy == .success)
    }

    // MARK: - Helpers
    private func makeTestJaneDoe() -> MockCredential {
        let testBundle = Bundle(for: BundleToken.self)
        return MockCredential.janeDoe(bundle: testBundle)
    }

    private func makeTestJaneDoeSigningFailure() -> MockCredential {
        let testBundle = Bundle(for: BundleToken.self)
        return MockCredential.janeDoeSigningFailure(bundle: testBundle)
    }

    private func makeTestJaneDoeAuthCancelledOnce() -> MockCredential {
        let testBundle = Bundle(for: BundleToken.self)
        return MockCredential.janeDoeAuthCancelledOnce(bundle: testBundle)
    }

    private func makeTestJaneDoeAbsentX5t() -> MockCredential {
        let testBundle = Bundle(for: BundleToken.self)
        return MockCredential.janeDoeAbsentX5t(bundle: testBundle)
    }
}

private class BundleToken {}
