import SwiftCBOR

public struct DocumentError {
    let docType: DocType
    let errorCode: UInt
    let errorMessage: String
    
    public init(docType: DocType, errorCode: UInt, errorMessage: String) {
        self.docType = docType
        self.errorCode = errorCode
        self.errorMessage = errorMessage
    }
}

extension DocumentError: CBOREncodable {
    public func toCBOR(options: CBOROptions = CBOROptions()) -> CBOR {
        .map([
            .docType: .utf8String(docType.rawValue),
            .errorCode: .unsignedInt(errorCode),
            .errorMessage: .utf8String(errorMessage)
        ])
    }
}

fileprivate extension CBOR {
    static var docType: CBOR { "docType" }
    static var errorCode: CBOR { "errorCode" }
    static var errorMessage: CBOR { "errorMessage" }
}
