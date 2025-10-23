import Foundation

struct DeviceEngagement {
    let version: String
    let security: Security
    let deviceRetrievalMethods: [DeviceRetrievalMethod]?
    
    init(
        version: String = "1.0",
        security: Security,
        deviceRetrievalMethods: [DeviceRetrievalMethod]?
    ) {
        self.version = version
        self.security = security
        self.deviceRetrievalMethods = deviceRetrievalMethods
    }
}
