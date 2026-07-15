import Foundation
import SwiftCBOR

// MARK: - SessionDataStatusCode

public enum SessionDataStatusCode: UInt64, Sendable {
    case sessionEncryption = 10
    case cborDecoding = 11
    case sessionTermination = 20
}

// MARK: - SessionDataError

public enum SessionDataError: LocalizedError, Equatable {
    case dataIsNotValidCBOR

    public var errorDescription: String? {
        "\(self): status code \(SessionDataStatusCode.cborDecoding.rawValue)"
    }
}

// MARK: - SessionData

public struct SessionData: Equatable, Sendable {
    public let data: Data?
    public let status: SessionDataStatusCode?

    public init(data: Data? = nil, status: SessionDataStatusCode? = nil) {
        self.data = data
        self.status = status
    }

    public init(fromCBOR rawData: Data) throws {
        guard let decodedCBOR = try? CBOR.decode([UInt8](rawData)),
              case let .map(map) = decodedCBOR else {
            throw SessionDataError.dataIsNotValidCBOR
        }

        if case let .byteString(bytes) = map[.data] {
            self.data = Data(bytes)
        } else {
            self.data = nil
        }

        if case let .unsignedInt(rawStatus) = map[.status] {
            self.status = SessionDataStatusCode(rawValue: rawStatus)
        } else {
            self.status = nil
        }
    }
}

// MARK: - CBOREncodable

extension SessionData: CBOREncodable {
    public func toCBOR(options: CBOROptions = CBOROptions()) -> CBOR {
        var map: [CBOR: CBOR] = [:]

        if let data {
            map[.data] = .byteString([UInt8](data))
        }

        if let status {
            map[.status] = .unsignedInt(status.rawValue)
        }

        return .map(map)
    }
}

fileprivate extension CBOR {
    static var data: CBOR { "data" }
    static var status: CBOR { "status" }
}
