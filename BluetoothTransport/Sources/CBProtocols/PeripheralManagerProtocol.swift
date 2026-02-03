import CoreBluetooth
import Foundation

/// A protocol defining the core responsibilities of a Bluetooth Peripheral Manager.
/// This abstraction facilitates dependency injection and unit testing for CoreBluetooth components.
public protocol PeripheralManagerProtocol: AnyObject {

    /// Returns the current authorization state of the peripheral manager.
    var authorization: CBManagerAuthorization { get }

    /// The current state of the peripheral manager (e.g., .poweredOn, .unauthorized).
    var state: CBManagerState { get }

    /// The delegate object that receives peripheral manager events.
    var delegate: CBPeripheralManagerDelegate? { get set }

    /// A Boolean value that indicates whether the peripheral is currently advertising data.
    var isAdvertising: Bool { get }

    /// Starts advertising the peripheral's data to nearby centrals.
    /// - Parameter advertisementData: A dictionary containing the data to be advertised.
    func startAdvertising(_ advertisementData: [String: Any]?)

    /// Stops advertising the peripheral's data.
    func stopAdvertising()

    /// Publishes a service and its associated characteristics to the local GATT database.
    /// - Parameter service: The service to be added.
    func add(_ service: CBMutableService)

    /// Removes a specific published service from the local GATT database.
    /// - Parameter service: The service to be removed.
    func remove(_ service: CBMutableService)

    /// Removes all published services from the local GATT database.
    func removeAllServices()

    /// Sends an updated characteristic value to one or more subscribed centrals via a notification or indication.
    /// - Parameters:
    ///   - value: The data to be sent.
    ///   - characteristic: The characteristic whose value has changed.
    ///   - onSubscribedCentrals: A list of centrals that should receive the update. Pass `nil` to update all subscribed centrals.
    /// - Returns: `true` if the update was sent successfully; `false` if the underlying transmit queue is full.
    func updateValue(
        _ value: Data,
        for characteristic: CBMutableCharacteristic,
        onSubscribedCentrals: [CBCentral]?
    ) -> Bool

    /// Responds to a read or write request from a connected central.
    ///
    /// This protocol-based method allows for dependency injection and unit testing
    /// of Bluetooth logic by abstracting the concrete `CBATTRequest` type.
    ///
    /// - Parameters:
    ///   - request: The specific ATT request received from the central.
    ///   - result: The result of the operation (e.g., .success, or a specific CBATTError).
    func respond(to request: any ATTRequestProtocol, withResult result: CBATTError.Code)
}

extension CBPeripheralManager: PeripheralManagerProtocol {
    /// Overrides the authorization property to map to the static class property.
    override public var authorization: CBManagerAuthorization {
        return CBPeripheralManager.authorization
    }

    /// Responds to a request by bridging the protocol-based request back to a concrete `CBATTRequest`.
    public func respond(to request: any ATTRequestProtocol, withResult result: CBATTError.Code) {
        if let nativeRequest = request as? CBATTRequest {
            self.respond(to: nativeRequest, withResult: result)
        }
    }
}
