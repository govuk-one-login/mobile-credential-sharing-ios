import SwiftCBOR

public struct DocumentError {
    public enum Code: UInt64 {
        case dataNotReturned = 0
    }
    
    let docType: DocType
    let code: Code
    let message: String
    
    public init(docType: DocType, code: Code, message: String) {
        self.docType = docType
        self.code = code
        self.message = message
    }
}

extension DocumentError: CBOREncodable {
    public func toCBOR(options: CBOROptions = CBOROptions()) -> CBOR {
        .map([
            .docType: .utf8String(docType.rawValue),
            .errorCode: .unsignedInt(code.rawValue),
            .errorMessage: .utf8String(message)
        ])
    }
}

fileprivate extension CBOR {
    static var docType: CBOR { "docType" }
    static var errorCode: CBOR { "errorCode" }
    static var errorMessage: CBOR { "errorMessage" }
}
