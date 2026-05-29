import GDSCommon
import UIKit

@MainActor
struct QRScannerViewModel: QRScanningViewModel {
    let title = "Scan QR Code"
    let instructionText = "Position the QR code within the viewfinder to scan"

    func didScan(value: String, in view: UIView) async {
        _ = value
        _ = view
        // TODO: DCMAW-19716 Process scanned QR code
    }
}
