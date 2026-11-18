import Testing

@testable import CredentialSharingUI

@Suite("SharingScreen Tests")
struct SharingScreenTests {

    @Test("Each screen exposes its firebase screen id")
    func screenIDs() {
        #expect(SharingScreen.getReadyToShare.id == "3f5c1d0b-8068-4e19-8300-37f7bb468ff5")
        #expect(SharingScreen.turnOnBluetooth.id == "d64962b9-def5-4b13-9c3c-128d51353fe7")
        #expect(SharingScreen.detailsShared.id == "c2ccd487-c0e0-4ef8-943b-c555c4856a2c")
        // TODO: DCMAW-24162 placeholder id until error screens are split out.
        #expect(SharingScreen.error.id == "0000")
    }

    @Test("Each screen maps to its taxonomy screen class")
    func screenClasses() {
        #expect(SharingScreen.getReadyToShare.screenClass == "READINESS")
        #expect(SharingScreen.turnOnBluetooth.screenClass == "READINESS")
        #expect(SharingScreen.detailsShared.screenClass == "RESOLUTION")
        #expect(SharingScreen.error.screenClass == "ERROR")
    }

    @Test("Each screen exposes its title localisation key")
    func titleKeys() {
        #expect(SharingScreen.getReadyToShare.title.key == "getReadyToShareTitle")
        #expect(SharingScreen.turnOnBluetooth.title.key == "turnOnBluetoothTitle")
        #expect(SharingScreen.detailsShared.title.key == "detailsSharedTitle")
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
        #expect(SharingEvent.consentCancelButton.title.key == "cancelAndGoBackButton")
        #expect(SharingEvent.cancel.title.substitutions.isEmpty)
        #expect(SharingEvent.consentCancelButton.title.substitutions.isEmpty)
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
