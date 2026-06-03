import Foundation
import SharingBluetoothTransport
import SharingCryptoService

/// A sequence of events called within the HolderOrchestrator that drives the flow
enum HolderOrchestratorEvent {
    case started
    case prerequisitesMet
    case advertisingStarted
    case bluetoothFailed(PeripheralError)
    case connectionEstablished
    case dataReceived(Data)
    case credentialValidated(DeviceRequest)
    case userApproved
    case responseReady
    case sendData(SessionData)
    case userDenied
    case sendCompleted
    case receivedEndRequest
    case userCancelled
}
