import Foundation
import SwiftCBOR

public enum RawCredentialParseError: LocalizedError {
    case msoDecodingFailed
}

public struct RawCredentialParser {
    
    public init() {
        // Empty init required to make struct public facing
    }
    
    public func parse(rawCredential: Data) throws -> ParsedRawCredential {
        guard let cbor = try CBOR.decode([UInt8](rawCredential)),
              case .map(let root) = cbor,
              case .array(let issuerAuth) = root[.issuerAuth],
              issuerAuth.count >= 3,
              case .byteString(let payload) = issuerAuth[2],
              let payloadCBOR = try CBOR.decode(payload),
              case .tagged(.encodedCBORDataItem, .byteString(let msoBytes)) = payloadCBOR,
              let msoCBOR = try CBOR.decode(msoBytes),
              case .map(let mso) = msoCBOR,
              case .utf8String(let docType) = mso[.docType]
        else {
            throw RawCredentialParseError.msoDecodingFailed
        }
        return ParsedRawCredential(docType: docType)
    }
}

private extension CBOR {
    static var issuerAuth: CBOR { "issuerAuth" }
    static var docType: CBOR { "docType" }
}
