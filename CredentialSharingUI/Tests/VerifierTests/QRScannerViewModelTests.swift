@testable import CredentialSharingUI
import Testing
import UIKit

@MainActor
@Suite("QRScannerViewModel Tests")
struct QRScannerViewModelTests {

    @Test("QRScannerViewModel has expected title")
    func title() {
        let viewModel = QRScannerViewModel()
        #expect(viewModel.title == "Scan QR Code")
    }

    @Test("QRScannerViewModel has expected instruction text")
    func instructionText() {
        let viewModel = QRScannerViewModel()
        #expect(viewModel.instructionText == "Position the QR code within the viewfinder to scan")
    }

    @Test("didScan completes without error")
    func didScan() async {
        let viewModel = QRScannerViewModel()
        await viewModel.didScan(value: "test", in: UIView())
    }
}
