import Foundation

enum DeviceRetrievalMethod {
    case bluetooth(BLEDeviceRetrievalMethodOptions)
    
    var type: UInt64 { 2 }
    var version: UInt64 { 1 }
}
