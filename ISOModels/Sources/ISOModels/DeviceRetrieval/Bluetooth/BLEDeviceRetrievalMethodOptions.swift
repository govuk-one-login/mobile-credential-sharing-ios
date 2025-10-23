import Foundation

enum BLEDeviceRetrievalMethodOptions {
    case peripheralOnly(PeripheralMode)
    case centralOnly(CentralMode)
    case either(PeripheralMode, CentralMode)
}
