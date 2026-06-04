import Foundation

// MARK: - Protocols

public protocol CentralSessionProtocol: AnyObject {
    var serviceUUID: UUID? { get }
}

public protocol CentralTransportProtocol: AnyObject {
    var delegate: CentralTransportDelegate? { get set }
    func startScanning(in session: CentralSessionProtocol) throws
    func stopScanning()
}

public protocol CentralTransportDelegate: AnyObject {
    func centralTransportDidPowerOn()
    func centralTransportDidDiscoverPeripheral()
    func centralTransportDidFail(with error: CentralError)
}

// MARK: - CentralTransport

public class CentralTransport: CentralTransportProtocol {
    private(set) var bleCentralTransport: BleCentralTransportProtocol

    public weak var delegate: CentralTransportDelegate?

    init(bleCentralTransport: BleCentralTransportProtocol) {
        self.bleCentralTransport = bleCentralTransport
        self.bleCentralTransport.delegate = self
    }

    public convenience init() {
        self.init(bleCentralTransport: BleCentralTransport())
    }

    public func startScanning(in session: CentralSessionProtocol) throws {
        try bleCentralTransport.startScanning(in: session)
    }

    public func stopScanning() {
        bleCentralTransport.handleDidStopScanning()
    }
}

// MARK: - BleCentralTransportDelegate

extension CentralTransport: BleCentralTransportDelegate {
    public func bleCentralTransportDidPowerOn() {
        delegate?.centralTransportDidPowerOn()
    }

    public func bleCentralTransportDidDiscoverPeripheral() {
        delegate?.centralTransportDidDiscoverPeripheral()
    }

    public func bleCentralTransportDidFail(with error: CentralError) {
        delegate?.centralTransportDidFail(with: error)
    }
}
