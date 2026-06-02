@testable import CredentialSharingUI
import Testing
import UIKit

@MainActor
@Suite("QRScannerViewModel Tests")
struct QRScannerViewModelTests {

    let orchestrator: VerifierOrchestratorProtocol = VerifierOrchestrator()
    @Test("QRScannerViewModel has expected title")
    func title() {
        let viewModel = QRScannerViewModel(orchestrator: orchestrator)
        #expect(viewModel.title == "Scan QR Code")
    }

    @Test("QRScannerViewModel has expected instruction text")
    func instructionText() {
        let viewModel = QRScannerViewModel(orchestrator: orchestrator)
        #expect(viewModel.instructionText == "Position the QR code within the viewfinder to scan")
    }

    @Test("didScan completes without error")
    func didScan() async {
        let viewModel = QRScannerViewModel(orchestrator: orchestrator)
        await viewModel.didScan(value: "test", in: UIView())
    }

    @Test("didScan passes scanned value to orchestrator qrCodeScanned")
    func didScanPassesValueToOrchestrator() async {
        let mockOrchestrator = MockVerifierOrchestrator()
        let viewModel = QRScannerViewModel(orchestrator: mockOrchestrator)

        await viewModel.didScan(value: "mdoc:engagementData", in: UIView())

        #expect(mockOrchestrator.qrCodeScannedValue == "mdoc:engagementData")
    }
}
