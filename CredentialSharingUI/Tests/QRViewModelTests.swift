@testable import CredentialSharingUI
import Testing
import UIKit

@MainActor
@Suite("QRViewModel Tests")
struct QRViewModelTests {

    @Test("QRViewModel has expected title")
    func title() {
        let viewModel = QRViewModel()
        #expect(viewModel.title == "Scan QR Code")
    }

    @Test("QRViewModel has expected instruction text")
    func instructionText() {
        let viewModel = QRViewModel()
        #expect(viewModel.instructionText == "Position the QR code within the viewfinder to scan")
    }

    @Test("didScan completes without error")
    func didScan() async {
        let viewModel = QRViewModel()
        await viewModel.didScan(value: "test", in: UIView())
    }
}
