import Foundation

struct DeviceEngagement {
    let version: String = "1.0"
    let security: Security
    let deviceRetrievalMethods: [DeviceRetrievalMethod]?
}
