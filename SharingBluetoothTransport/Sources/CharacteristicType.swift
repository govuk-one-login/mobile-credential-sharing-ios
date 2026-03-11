import CoreBluetooth

enum CharacteristicType: String, CaseIterable {
    case state = "00000001-A123-48CE-896B-4C76973373E6"
    case clientToServer = "00000002-A123-48CE-896B-4C76973373E6"
    case serverToClient = "00000003-A123-48CE-896B-4C76973373E6"

    var uuid: CBUUID {
        return CBUUID(string: self.rawValue)
    }
    
    var properties: CBCharacteristicProperties {
        switch self {
        case .state:
            [.notify, .writeWithoutResponse]
        case .clientToServer:
            [.writeWithoutResponse]
        case .serverToClient:
            [.notify]
        }
    }
}
