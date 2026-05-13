import Foundation
import SwiftCBOR

public enum RawCredentialParseError: LocalizedError {
    case msoDecodingFailed
    case nameSpacesDecodingFailed
}

public struct RawCredentialParser {
    
    public init() {
        // Empty init required to make struct public facing
    }
    
    public func parse(rawCredential: Data) throws -> ParsedRawCredential {
        guard let cbor = try CBOR.decode([UInt8](rawCredential)),
              case .map(let root) = cbor,
              case .array(let issuerAuthArray) = root[.issuerAuth],
              issuerAuthArray.count >= 3,
              case .byteString(let payload) = issuerAuthArray[2],
              let payloadCBOR = try CBOR.decode(payload),
              case .tagged(.encodedCBORDataItem, .byteString(let msoBytes)) = payloadCBOR,
              let msoCBOR = try CBOR.decode(msoBytes),
              case .map(let mso) = msoCBOR,
              case .utf8String(let docType) = mso[.docType]
        else {
            throw RawCredentialParseError.msoDecodingFailed
        }

        let issuerAuthBytes = CBOR.array(issuerAuthArray).encode()
        let nameSpaces = try parseNameSpaces(from: root)

        return ParsedRawCredential(
            docType: docType,
            nameSpaces: nameSpaces,
            issuerAuth: issuerAuthBytes
        )
    }

    private func parseNameSpaces(from root: [CBOR: CBOR]) throws -> [String: [IssuerSignedItemBytes]] {
        guard case .map(let nameSpacesMap) = root[.nameSpaces] else {
            throw RawCredentialParseError.nameSpacesDecodingFailed
        }

        var result: [String: [IssuerSignedItemBytes]] = [:]
        for (key, value) in nameSpacesMap {
            guard case .utf8String(let nsName) = key,
                  case .array(let items) = value else {
                throw RawCredentialParseError.nameSpacesDecodingFailed
            }
            result[nsName] = try items.map { item in
                guard case .tagged(.encodedCBORDataItem, .byteString(let itemBytes)) = item,
                      let decoded = try CBOR.decode(itemBytes),
                      case .map(let itemMap) = decoded,
                      case .utf8String(let identifier) = itemMap[.elementIdentifier] else {
                    throw RawCredentialParseError.nameSpacesDecodingFailed
                }
                let elementValue = itemMap[.elementValue] ?? .null
                return IssuerSignedItemBytes(
                    elementIdentifier: identifier,
                    elementValue: elementValue,
                    rawCBOR: item
                )
            }
        }
        return result
    }
}

private extension CBOR {
    static var issuerAuth: CBOR { "issuerAuth" }
    static var nameSpaces: CBOR { "nameSpaces" }
    static var docType: CBOR { "docType" }
    static var elementIdentifier: CBOR { "elementIdentifier" }
    static var elementValue: CBOR { "elementValue" }
}
