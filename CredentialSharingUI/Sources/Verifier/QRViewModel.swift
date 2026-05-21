import GDSCommon
import UIKit

@MainActor
struct QRViewModel: QRScanningViewModel {
    let title = "Scan QR Code"
    let instructionText = "Position the QR code within the viewfinder to scan"

    func didScan(value: String, in view: UIView) async {
        // TODO: DCMAW-19716 Process scanned QR code
    }
}
