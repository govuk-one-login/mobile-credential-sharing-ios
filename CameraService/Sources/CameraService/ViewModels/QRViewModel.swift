import GDSCommon
import ISOModels
import UIKit

// MARK: - QR Scanning ViewModel

@MainActor
struct QRViewModel: QRScanningViewModel {
    let title: String
    let instructionText: String
    let dismissScanner: @Sendable () async -> Void
    let presentInvalidQRError: @Sendable () async -> Void

    func didScan(value: String, in _: UIView) async {
        if isMdocString(value) {
            // Dismiss scanner to prevent multiple scans
            await dismissScanner()
            await handleMdocScanned(value: value)
        } else {
            // All non-mdoc content redirects to error view
            await dismissScanner()
            await handleInvalidQRScanned(value: value)
        }
    }

    internal func extractURL(from value: String) -> URL? {
        if isMdocString(value) {
            return nil
        }

        // Create URL directly from the value
        if let url = URL(string: value), url.scheme != nil {
            return url
        }
        // If that doesn't work, then find URL within the text
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(location: 0, length: value.utf16.count)
        if let match = detector?.firstMatch(in: value, options: [], range: range),
           let url = match.url {
            return url
        }
        return nil
    }

    internal func isMdocString(_ value: String) -> Bool {
        return value.lowercased().hasPrefix("mdoc:")
    }

    @MainActor
    private func handleMdocScanned(value: String) async {
        print("QR Code scanned - compliant QR code with valid URI: \(value)")
        let mdocString = String(value.dropFirst("mdoc:".count))
        let decodedResult = await decodeMdoc(mdocString)
        print("Mdoc decoded result: \n\(decodedResult.debugDescription)")
    }

    @MainActor
    private func handleInvalidQRScanned(value: String) async {
        print("QR Code scanned - invalid QR code, showing error view. Content: \(value)")
        await presentInvalidQRError()
    }

    // todo: DCMAW-18234 - will need to refactor when new architecture is introduced
    private func decodeMdoc(_ mdocString: String) async -> DeviceEngagement? {
        do {
            let result = try DeviceEngagement(from: mdocString)
            return result
        } catch {
            await presentInvalidQRError()
            return nil
        }
    }
}
