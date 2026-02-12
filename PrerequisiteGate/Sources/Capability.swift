import AVFoundation
import CoreBluetooth

public enum Capability: CaseIterable, Sendable, Hashable, Equatable {
    
    case bluetooth(CBManagerAuthorization = CBManager.authorization)
    case camera
    
    public static let allCases: [Capability] = [.bluetooth(CBManager.authorization), .camera]
   
    var isAllowed: Bool {
        switch self {
        case .bluetooth:
            return CBManager.authorization == .allowedAlways
        case .camera:
            return AVCaptureDevice.default(for: .video) != nil &&
            AVCaptureDevice.authorizationStatus(for: .video) == .authorized
        }
    }
    
    public var rawValue: String {
        switch self {
        case .bluetooth:
            return "Bluetooth"
        case .camera:
            return "Camera"
        }
    }
}
