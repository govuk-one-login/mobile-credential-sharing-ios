import SwiftCBOR

public struct Document {
    let docType: DocType
    let issuerSigned: IssuerSigned
    let deviceSigned: DeviceSigned?
    let errors: [String: UInt]?
    
    public init(
        docType: DocType,
        issuerSigned: IssuerSigned,
        deviceSigned: DeviceSigned? = nil,
        errors: [String: UInt]? = nil
    ) {
        self.docType = docType
        self.issuerSigned = issuerSigned
        self.deviceSigned = deviceSigned
        self.errors = errors
    }
}

extension Document: CBOREncodable {
    public func toCBOR(options: CBOROptions = CBOROptions()) -> CBOR {
        var map: [CBOR: CBOR] = [
            .docType: .utf8String(docType.rawValue),
            .issuerSigned: issuerSigned.toCBOR(options: options)
        ]
        
        if let deviceSigned = deviceSigned {
            map[.deviceSigned] = deviceSigned.toCBOR(options: options)
        }
        
        if let errors = errors {
            map[.errors] = .map(errors.mapKeys { .utf8String($0) }.mapValues { .unsignedInt($0) })
        }
        
        return .map(map)
    }
}

fileprivate extension CBOR {
    static var docType: CBOR { "docType" }
    static var issuerSigned: CBOR { "issuerSigned" }
    static var deviceSigned: CBOR { "deviceSigned" }
    static var errors: CBOR { "errors" }
}

fileprivate extension Dictionary {
    func mapKeys<T>(_ transform: (Key) -> T) -> [T: Value] {
        [T: Value](uniqueKeysWithValues: map { (transform($0.key), $0.value) })
    }
}
