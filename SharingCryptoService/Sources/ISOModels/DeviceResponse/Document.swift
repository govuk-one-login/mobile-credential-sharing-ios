import SwiftCBOR

public struct Document: Equatable, Hashable, Sendable {
    public let docType: DocType
    public let issuerSigned: IssuerSigned
    let deviceSigned: DeviceSigned?
    let errors: [DocumentError]?
    
    public init(
        docType: DocType,
        issuerSigned: IssuerSigned,
        deviceSigned: DeviceSigned? = nil,
        errors: [DocumentError]? = nil
    ) {
        self.docType = docType
        self.issuerSigned = issuerSigned
        self.deviceSigned = deviceSigned
        self.errors = errors
    }

    /// Decodes a `Document` from a CBOR value.
    init(cbor: CBOR) throws {
        guard case let .map(documentMap) = cbor,
              case let .utf8String(docTypeRaw) = documentMap[.docType],
              let docType = DocType(rawValue: docTypeRaw)
        else {
            throw DeviceResponseError.cborDecodingError
        }

        guard let issuerSignedCBOR = documentMap[.issuerSigned] else {
            throw DeviceResponseError.cborDecodingError
        }

        let issuerSigned = try IssuerSigned(cbor: issuerSignedCBOR)

        self.docType = docType
        self.issuerSigned = issuerSigned
        // deviceSigned and errors are unsupported optional fields — ignored
        self.deviceSigned = nil
        self.errors = nil
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
            map[.errors] = .map(errors.reduce(into: [:]) { result, error in
                result[.utf8String(error.docType.rawValue)] = .unsignedInt(error.code.rawValue)
            })
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
