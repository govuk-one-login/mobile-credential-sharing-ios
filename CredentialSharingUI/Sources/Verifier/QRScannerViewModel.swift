import GDSCommon
import UIKit

@MainActor
struct QRScannerViewModel: QRScanningViewModel {
    let orchestrator: VerifierOrchestratorProtocol
    let title = "Scan QR Code"
    let instructionText = "Position the QR code within the viewfinder to scan"

    func didScan(value: String, in view: UIView) async {
        _ = value
        _ = view
        orchestrator.qrCodeScanned(value)
        // TODO: DCMAW-19716 Process scanned QR code
    }
}
