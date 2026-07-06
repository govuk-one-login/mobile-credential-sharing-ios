@testable import SharingCryptoService

enum MockDeviceRequest {
    static var standard: DeviceRequest? {
        let group = AttributeGroup(
            mdlAttributes: [.init(attribute: .familyName, intentToRetain: true),
                            .init(attribute: .portrait, intentToRetain: false),
                            .init(attribute: .ageOver(23), intentToRetain: false)],
            gbMdlAttributes: [.init(attribute: .title, intentToRetain: false)]
        )
        guard let group = group else { return nil }
        return DeviceRequest(docRequests: [
            DocRequest(
                with: group
            )
        ])
    }
}
