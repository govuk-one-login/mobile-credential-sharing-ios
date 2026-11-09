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
        #expect(SharingScreen.getReadyToShare.titleKey == "getReadyToShareTitle")
        #expect(SharingScreen.turnOnBluetooth.titleKey == "turnOnBluetoothTitle")
        #expect(SharingScreen.detailsShared.titleKey == "detailsSharedTitle")
        #expect(SharingScreen.error.titleKey == "error")
    }
}
