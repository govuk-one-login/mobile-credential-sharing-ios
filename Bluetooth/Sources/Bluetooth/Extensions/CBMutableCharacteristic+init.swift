import CoreBluetooth

extension CBMutableCharacteristic {
    convenience init(characteristic: CharacteristicType) {
        self.init(
            type: CBUUID(string: characteristic.rawValue),
            properties: characteristic.properties,
            value: nil,
            permissions: [.readable, .writeable]
        )
        let descriptor = CBMutableDescriptor(
            type: CBUUID(string: CBUUIDCharacteristicUserDescriptionString),
            value: "\(characteristic) characteristic"
        )
        self.descriptors = [descriptor]
    }
}
