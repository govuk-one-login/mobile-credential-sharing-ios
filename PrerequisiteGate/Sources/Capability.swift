import AVFoundation
import CoreBluetooth

public enum Capability: CaseIterable, Sendable {
    case bluetooth
    case camera
   
    var isAllowed: Bool {
        switch self {
        case .bluetooth:
            return CBManager.authorization == .allowedAlways
        case .camera:
            return AVCaptureDevice.default(for: .video) != nil &&
            AVCaptureDevice.authorizationStatus(for: .video) == .authorized
        }
    }
}
