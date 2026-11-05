import Testing

@testable import CredentialSharingUI

@Suite("SharingScreen Tests")
struct SharingScreenTests {

    @Test("Each screen exposes its firebase screen id")
    func screenIDs() {
        #expect(SharingScreen.getReadyToShare.id == "3f5c1d0b-8068-4e19-8300-37f7bb468ff5")
        #expect(SharingScreen.turnOnBluetooth.id == "d64962b9-def5-4b13-9c3c-128d51353fe7")
        #expect(SharingScreen.detailsShared.id == "c2ccd487-c0e0-4ef8-943b-c555c4856a2c")
    }

    @Test("Each screen maps to its taxonomy screen class")
    func screenClasses() {
        #expect(SharingScreen.getReadyToShare.screenClass == "READINESS")
        #expect(SharingScreen.turnOnBluetooth.screenClass == "READINESS")
        #expect(SharingScreen.detailsShared.screenClass == "RESOLUTION")
    }

    @Test("Each screen resolves its English title from the SDK string catalogue")
    func englishTitles() {
        #expect(SharingScreen.getReadyToShare.englishTitle == "Get ready to share")
        #expect(SharingScreen.turnOnBluetooth.englishTitle == "Turn on Bluetooth")
        #expect(SharingScreen.detailsShared.englishTitle == "Details shared")
    }
}

@Suite("SharingEvent Tests")
struct SharingEventTests {

    @Test("Each event resolves its English title from the SDK string catalogue")
    func englishTitles() {
        #expect(SharingEvent.cancel.englishTitle == "Cancel")
        #expect(SharingEvent.getReadyToShareFindOutHowButton.englishTitle == "Find out how sharing works")
        #expect(SharingEvent.getReadyToShareAllowBluetoothButton.englishTitle == "Allow Bluetooth")
        #expect(SharingEvent.detailsSharedGoBackButton.englishTitle == "Go back to documents")
    }
}
