import Foundation
@testable import SharingCryptoService
import SwiftCBOR
import Testing

// MARK: - DeviceEngagement Generation

/// Builds a valid `DeviceEngagement` using the device's own ISO models and encodes it to CBOR bytes.
///
/// This drives the same production types (`DeviceEngagement`, `Security`, `EDeviceKey`,
/// `DeviceRetrievalMethod`) and the same `CBOREncodable` path the mdoc uses on the wire, rather than
/// relying on a static hex fixture. The resulting bytes are what the mdoc would actually transmit in
/// the QR / NFC engagement.
///
/// Structure (ISO/IEC 18013-5:2021 §8.2.1.1):
/// DeviceEngagement = {
///   0: tstr,                       ; Version ("1.0")
///   1: Security,                   ; [cipherSuiteIdentifier, EDeviceKeyBytes]
///   ? 2: [+ DeviceRetrievalMethod] ; DeviceRetrievalMethods
/// }
///
/// Security = [
///   int,                           ; cipher suite identifier (1)
///   #6.24(bstr .cbor COSE_Key)     ; EDeviceKeyBytes
/// ]
///
/// - Returns: The CBOR-encoded DeviceEngagement bytes produced by the device models.
func makeValidDeviceEngagementData() -> Data {
    let engagement = makeValidDeviceEngagement()
    return Data(engagement.toCBOR(options: CBOROptions()).encode())
}

/// Builds a valid `DeviceEngagement` model instance with a P-256 EDeviceKey, the ISO 18013 cipher
/// suite (identifier 1), and a single BLE peripheral-only device retrieval method.
func makeValidDeviceEngagement() -> DeviceEngagement {
    // A representative (test) uncompressed P-256 public key. The exact coordinate values are not
    // asserted by these structural tests; only their CBOR encoding (bstr) matters.
    let xCoordinate: [UInt8] = [
        0x55, 0xFB, 0xE1, 0x84, 0x25, 0x53, 0x4E, 0xCD, 0x6D, 0x2F, 0xEE, 0x9A, 0x41, 0xE9, 0xB1, 0x79,
        0xC0, 0xB1, 0xFC, 0x4D, 0x62, 0x2F, 0xE1, 0x7C, 0xBE, 0x72, 0xA1, 0x96, 0x58, 0xBD, 0x68, 0x05
    ]
    let yCoordinate: [UInt8] = [
        0x7F, 0x0E, 0xFE, 0x02, 0x4C, 0xBB, 0xD0, 0xDF, 0x2C, 0x13, 0x29, 0x0B, 0x84, 0xA0, 0x34, 0x99,
        0xF7, 0x09, 0xC3, 0xAB, 0x96, 0x85, 0x24, 0x62, 0xDF, 0x24, 0x53, 0x40, 0xB0, 0xEA, 0xB2, 0xE5
    ]
    let eDeviceKey = EDeviceKey(
        curve: .p256,
        xCoordinate: xCoordinate,
        yCoordinate: yCoordinate
    )
    let security = Security(
        cipherSuiteIdentifier: .iso18013,
        eDeviceKey: eDeviceKey
    )
    let retrievalMethod: DeviceRetrievalMethod = .bluetooth(
        .peripheralOnly(
            PeripheralMode(
                uuid: UUID(uuidString: "6CAA059E-041A-453F-9029-8698BF559809") ?? UUID()
            )
        )
    )
    return DeviceEngagement(
        security: security,
        deviceRetrievalMethods: [retrievalMethod]
    )
}

// MARK: - CBOR Navigation Helpers

/// Decodes DeviceEngagement bytes into the top-level CBOR map, failing the test with a clear message
/// if the structure is not a map.
func decodeDeviceEngagementMap(_ data: Data) throws -> [CBOR: CBOR] {
    let decoded = try #require(try CBOR.decode([UInt8](data)), "DeviceEngagement must be well-formed CBOR")
    guard case .map(let pairs) = decoded else {
        Issue.record("DeviceEngagement must decode to a CBOR map (major type 5)")
        return [:]
    }
    return pairs
}

/// Extracts the Security array (`DeviceEngagement` key 1) from a decoded DeviceEngagement map.
func extractSecurityArray(from pairs: [CBOR: CBOR]) throws -> [CBOR] {
    guard case .array(let security) = pairs[.unsignedInt(1)] else {
        Issue.record("Security (key 1) must be present and be an array")
        return []
    }
    return security
}
