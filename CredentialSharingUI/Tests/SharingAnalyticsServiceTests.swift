import Testing

@testable import CredentialSharingUI

@Suite("SharingScreen Tests")
struct SharingScreenTests {

    @Test("Each screen exposes its firebase screen id")
    func screenIDs() {
        #expect(SharingScreen.getReadyToShare.id == "3f5c1d0b-8068-4e19-8300-37f7bb468ff5")
        #expect(SharingScreen.turnOnBluetooth.id == "d64962b9-def5-4b13-9c3c-128d51353fe7")
        #expect(SharingScreen.bluetoothPermissionDenied.id == "9b4d6c72-2af5-4f9a-aadd-e9ac3ad1ccb8")
        #expect(SharingScreen.detailsShared.id == "c2ccd487-c0e0-4ef8-943b-c555c4856a2c")
        #expect(SharingScreen.genericError.id == "9bf821af-e8ff-41cf-a311-4b6cec989315")
        #expect(SharingScreen.readerAuthError.id == "d3e44133-024c-4ce8-84bf-7bed9c01ff96")
        #expect(SharingScreen.unfulfillableRequest.id == "1c5c61b3-b8d4-4355-9be3-b26440a43b3f")
        #expect(SharingScreen.unfulfillableRequest.screenClass == "RESOLUTION")
        #expect(SharingScreen.unfulfillableRequest.title.key == "unfulfillableRequestTitle")
        #expect(SharingScreen.bluetoothConnectionError.id == "c70e0a2f-7818-4561-b41a-7dc8528856ae")
        // Legacy placeholder id, used by `ErrorViewController` until its failures migrate.
        #expect(SharingScreen.error.id == "0000")
    }

    @Test("Each screen maps to its taxonomy screen class")
    func screenClasses() {
        #expect(SharingScreen.getReadyToShare.screenClass == "READINESS")
        #expect(SharingScreen.turnOnBluetooth.screenClass == "READINESS")
        #expect(SharingScreen.bluetoothPermissionDenied.screenClass == "READINESS")
        #expect(SharingScreen.detailsShared.screenClass == "RESOLUTION")
        #expect(SharingScreen.genericError.screenClass == "RESOLUTION")
        #expect(SharingScreen.readerAuthError.screenClass == "RESOLUTION")
        #expect(SharingScreen.bluetoothConnectionError.screenClass == "RESOLUTION")
        #expect(SharingScreen.error.screenClass == "ERROR")
    }

    @Test("Each screen exposes its title localisation key")
    func titleKeys() {
        #expect(SharingScreen.getReadyToShare.title.key == "getReadyToShareTitle")
        #expect(SharingScreen.turnOnBluetooth.title.key == "turnOnBluetoothTitle")
        #expect(SharingScreen.detailsShared.title.key == "detailsSharedTitle")
        #expect(SharingScreen.genericError.title.key == "genericErrorTitle")
        #expect(SharingScreen.readerAuthError.title.key == "readerAuthErrorTitle")
        #expect(SharingScreen.bluetoothConnectionError.title.key == "bluetoothConnectionErrorTitle")
        #expect(SharingScreen.error.title.key == "error")
    }

    @Test("Title substitutions keep the real DVS name out of analytics")
    func titleSubstitutions() {
        // Only More about DVS substitutes a literal; its title template carries a
        // placeholder that must not be filled with the real provider name.
        #expect(SharingScreen.moreAboutDVS.title.key == "moreAboutDVSTitle")
        #expect(SharingScreen.moreAboutDVS.title.substitutions == ["dvsAnalyticsName"])

        // Screens with static titles declare no substitutions.
        #expect(SharingScreen.getReadyToShare.title.substitutions.isEmpty)
        #expect(SharingScreen.detailsShared.title.substitutions.isEmpty)
    }
}

@Suite("SharingEvent Tests")
struct SharingEventTests {

    @Test("Events reuse their on-screen copy key with no substitutions by default")
    func reusesDisplayKey() {
        #expect(SharingEvent.cancel.title.key == "cancel")
        #expect(SharingEvent.close.title.key == "close")
        #expect(SharingEvent.goBackToDocumentsButton.title.key == "goBackToDocumentsButton")
        #expect(SharingEvent.cancelAndGoBackButton.title.key == "cancelAndGoBackButton")
        #expect(SharingEvent.tryAgainWithNewQRCodeButton.title.key == "tryAgainWithNewQRCodeButton")
        #expect(SharingEvent.cancel.title.substitutions.isEmpty)
        #expect(SharingEvent.cancelAndGoBackButton.title.substitutions.isEmpty)
    }

    @Test("DVS-bearing events substitute the DVS literal instead of the real name")
    func substitutesDVSName() {
        #expect(SharingEvent.consentReadAboutButton.title.key == "consentReadAboutButton")
        #expect(SharingEvent.consentReadAboutButton.title.substitutions == ["dvsAnalyticsName"])
        #expect(SharingEvent.dvsPrivacyNotice.title.key == "dvsPrivacyNotice")
        #expect(SharingEvent.dvsPrivacyNotice.title.substitutions == ["dvsAnalyticsName"])
    }

    @Test("Agree button uses a dedicated analytics key that omits the item count")
    func agreeButtonUsesAnalyticsKey() {
        #expect(SharingEvent.consentAgreeButton.title.key == "consentAgreeButtonAnalytics")
        #expect(SharingEvent.consentAgreeButton.title.substitutions.isEmpty)
    }
}
