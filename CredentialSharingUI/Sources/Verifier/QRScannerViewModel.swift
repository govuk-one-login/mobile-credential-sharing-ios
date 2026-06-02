import GDSCommon
import UIKit

@MainActor
struct QRScannerViewModel: QRScanningViewModel {
    let orchestrator: VerifierOrchestratorProtocol
    let title = "Scan QR Code"
    let instructionText = "Position the QR code within the viewfinder to scan"

    func didScan(value: String, in view: UIView) async {
        orchestrator.qrCodeScanned(value)
    }
}
