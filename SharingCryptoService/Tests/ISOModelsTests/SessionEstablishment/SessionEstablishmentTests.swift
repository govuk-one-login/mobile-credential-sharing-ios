import Foundation
@testable import SharingCryptoService
import SwiftCBOR
import Testing

// swiftlint:disable line_length
@Suite("SessionEstablishment Tests")
struct SessionEstablishmentTests {
    // Mock data taken from ISO 18013-5
    let sessionEstablishmentBase64 =
    """
    omplUmVhZGVyS2V52BhYS6QBAiABIVggYOM5I4UEH1FAMFHyQVUxy1bdP5mccWhwE6rGdovIGH4iWCDljeuP2+kH991TaCRVUaNHlvfSIVxEDDObsPe2e+zN+mRkYXRhWQLfUq2irL62w5DyygvGWbSEZ465TdRQdDhqreziN3e0RgbkLihGvC4u48HoZ7HRaF5BNUoCGrsP2jbwnPXVxRtWHTvkHJNHrnHPK0nenex7RARqsCJHkxshDJFXhAwVFKYCewiBBxat9hlmNEl5MUrDrp9A5m4BXBJUpoQQi9CT6HcuwzP7Zj/WgDrwLqEL2+g6mZ91tVoYD4chOftXrASs1YyhXsoVDN4cO4SUARiLejDOiH3XtxsS7aL8bsblI1pslJg1H80wHyKSpOu6dVUoXO6E6tlu8Wd7Cvgjn2p6Uq9LiAmx1SqyGhYsoxreIcV70dmXCigyqsQcfVLRxP7k7mQDCiGN9RNjvnAXkvpsUVxIm9Odytb7pI8dbrGenHaVMaO/mZijLAGEEwXyOETKPbah/w0NkXND1i/HKtWOqwGjGYEW8ZYGYJ+U416st40jxZxnhSo2GRX+h4SM26VjDJn6txrv9y0THPRCZU93COxIIWQW8tmWz2z5EBK3cbiJB7HRYp36eUND5lPDEgdILi9mIc1LXc87PDKGJcM/6YvpnF8mSiZDFb5Buv3HJvi83lkg3gpxiE2GCvRMH/Gz14sujXINhdrlP+orP6GAYWKkvgLQOVZ8XrJBnCrYea9I/LffVcqU8bAPYhh/ojKcgieq4BMOwFLKPiEC5X5ykRsyjP3Puq9rk2RmD2E0FTgmRMMMC9TiIsXPlLpac2ecU9XO2VylB4fCKJoMFzWDk8Hg8icjYQAvubFgYGiIpZ73osOJ9ot8tCRXLbAmsXzyvcr8tnyCktkrUAUDVpAKYqgrFvhUdZBSsA8PRnOkYin0Mlfo6DJUAbP+zIxtIli69/fC+7r6s6G2re1Ozqwer9W2ERjfk7wKYisDUE/eR867Ik6YPbEmd+MWwiquBC1s5K2uDYsPQEN7jhr6CFnJUBvrY5dEloWaYPEQabGWW0/6xXealhkfierHyqaIueZ8
    """.filter { !$0.isWhitespace }
    
    @Test("Valid data is successfully decoded into SessionEstablishment")
    func successfullyDecodesSessionEstablishment() async throws {
        let data = try #require(Data(base64Encoded: sessionEstablishmentBase64))
        let decodedSessionEstablishment = try SessionEstablishment(rawData: data)
        print(decodedSessionEstablishment)
        
        let eReaderKeyBytes = [UInt8](
            try #require(
                Data(
                    base64Encoded: "pAECIAEhWCBg4zkjhQQfUUAwUfJBVTHLVt0/mZxxaHATqsZ2i8gYfiJYIOWN64/b6Qf33VNoJFVRo0eW99IhXEQMM5uw97Z77M36"
                )
            )
        )
        #expect(
            decodedSessionEstablishment.eReaderKeyBytes == eReaderKeyBytes
        )
        
        let base64Data = [UInt8](
            try #require(
                Data(
                    base64Encoded: "Uq2irL62w5DyygvGWbSEZ465TdRQdDhqreziN3e0RgbkLihGvC4u48HoZ7HRaF5BNUoCGrsP2jbwnPXVxRtWHTvkHJNHrnHPK0nenex7RARqsCJHkxshDJFXhAwVFKYCewiBBxat9hlmNEl5MUrDrp9A5m4BXBJUpoQQi9CT6HcuwzP7Zj/WgDrwLqEL2+g6mZ91tVoYD4chOftXrASs1YyhXsoVDN4cO4SUARiLejDOiH3XtxsS7aL8bsblI1pslJg1H80wHyKSpOu6dVUoXO6E6tlu8Wd7Cvgjn2p6Uq9LiAmx1SqyGhYsoxreIcV70dmXCigyqsQcfVLRxP7k7mQDCiGN9RNjvnAXkvpsUVxIm9Odytb7pI8dbrGenHaVMaO/mZijLAGEEwXyOETKPbah/w0NkXND1i/HKtWOqwGjGYEW8ZYGYJ+U416st40jxZxnhSo2GRX+h4SM26VjDJn6txrv9y0THPRCZU93COxIIWQW8tmWz2z5EBK3cbiJB7HRYp36eUND5lPDEgdILi9mIc1LXc87PDKGJcM/6YvpnF8mSiZDFb5Buv3HJvi83lkg3gpxiE2GCvRMH/Gz14sujXINhdrlP+orP6GAYWKkvgLQOVZ8XrJBnCrYea9I/LffVcqU8bAPYhh/ojKcgieq4BMOwFLKPiEC5X5ykRsyjP3Puq9rk2RmD2E0FTgmRMMMC9TiIsXPlLpac2ecU9XO2VylB4fCKJoMFzWDk8Hg8icjYQAvubFgYGiIpZ73osOJ9ot8tCRXLbAmsXzyvcr8tnyCktkrUAUDVpAKYqgrFvhUdZBSsA8PRnOkYin0Mlfo6DJUAbP+zIxtIli69/fC+7r6s6G2re1Ozqwer9W2ERjfk7wKYisDUE/eR867Ik6YPbEmd+MWwiquBC1s5K2uDYsPQEN7jhr6CFnJUBvrY5dEloWaYPEQabGWW0/6xXealhkfierHyqaIueZ8"
                )
            )
        )
        #expect(decodedSessionEstablishment.data == base64Data)
    }
    
    @Test("Invalid data structure - no CBOR map - throws an error on decoding")
    func invalidCBORNoMapThrowsAnError() throws {
        let data = Data([0x01])
        
        #expect(
            throws: SessionEstablishmentError.cborMapMissing
        ) {
            try SessionEstablishment(rawData: data)
        }
    }
    
    @Test("Invalid data structure - no CBOR 'eReaderKey' - throws an error on decoding")
    func invalidCBORNoEReaderKeyThrowsAnError() throws {
        let noEReaderKeyField = try #require(Data(base64Encoded: "oWRkYXRhWQLfUq2irL62w5DyygvGWbSEZ465TdRQdDhqreziN3e0RgbkLihGvC4u48HoZ7HRaF5BNUoCGrsP2jbwnPXVxRtWHTvkHJNHrnHPK0nenex7RARqsCJHkxshDJFXhAwVFKYCewiBBxat9hlmNEl5MUrDrp9A5m4BXBJUpoQQi9CT6HcuwzP7Zj/WgDrwLqEL2+g6mZ91tVoYD4chOftXrASs1YyhXsoVDN4cO4SUARiLejDOiH3XtxsS7aL8bsblI1pslJg1H80wHyKSpOu6dVUoXO6E6tlu8Wd7Cvgjn2p6Uq9LiAmx1SqyGhYsoxreIcV70dmXCigyqsQcfVLRxP7k7mQDCiGN9RNjvnAXkvpsUVxIm9Odytb7pI8dbrGenHaVMaO/mZijLAGEEwXyOETKPbah/w0NkXND1i/HKtWOqwGjGYEW8ZYGYJ+U416st40jxZxnhSo2GRX+h4SM26VjDJn6txrv9y0THPRCZU93COxIIWQW8tmWz2z5EBK3cbiJB7HRYp36eUND5lPDEgdILi9mIc1LXc87PDKGJcM/6YvpnF8mSiZDFb5Buv3HJvi83lkg3gpxiE2GCvRMH/Gz14sujXINhdrlP+orP6GAYWKkvgLQOVZ8XrJBnCrYea9I/LffVcqU8bAPYhh/ojKcgieq4BMOwFLKPiEC5X5ykRsyjP3Puq9rk2RmD2E0FTgmRMMMC9TiIsXPlLpac2ecU9XO2VylB4fCKJoMFzWDk8Hg8icjYQAvubFgYGiIpZ73osOJ9ot8tCRXLbAmsXzyvcr8tnyCktkrUAUDVpAKYqgrFvhUdZBSsA8PRnOkYin0Mlfo6DJUAbP+zIxtIli69/fC+7r6s6G2re1Ozqwer9W2ERjfk7wKYisDUE/eR867Ik6YPbEmd+MWwiquBC1s5K2uDYsPQEN7jhr6CFnJUBvrY5dEloWaYPEQabGWW0/6xXealhkfierHyqaIueZ8"))
        
        #expect(
            throws: SessionEstablishmentError.cborEReaderKeyFieldMissing
        ) {
            try SessionEstablishment(rawData: noEReaderKeyField)
        }
    }
    
    @Test("Invalid data structure - no CBOR 'data' - throws an error on decoding")
    func invalidCBORNoDataThrowsAnError() throws {
        let noDataField = try #require(Data(base64Encoded: "oWplUmVhZGVyS2V52BhYS6QBAiABIVggYOM5I4UEH1FAMFHyQVUxy1bdP5mccWhwE6rGdovIGH4iWCDljeuP2+kH991TaCRVUaNHlvfSIVxEDDObsPe2e+zN+g=="))
        
        #expect(
            throws: SessionEstablishmentError.cborDataFieldMissing
        ) {
            try SessionEstablishment(rawData: noDataField)
        }
    }
    
    @Test("SessionEstablishmentError descriptions are correct")
    func sessionEstablishmentErrorDescriptions() {
        for error in [
            SessionEstablishmentError.cborMapMissing,
            .cborEReaderKeyFieldMissing,
            .cborDataFieldMissing
        ] {
            switch error {
            case .cborMapMissing:
                #expect(error.errorDescription == "CBOR decoding error: SessionEstablishment contains invalid CBOR encoding (status code 11 CBOR decoding error)")
            case .cborEReaderKeyFieldMissing:
                #expect(error.errorDescription == "CBOR parsing error: SessionEstablishment missing mandatory key 'eReaderKey' (status code 12 CBOR validation error)")
            case .cborDataFieldMissing:
                #expect(error.errorDescription == "CBOR parsing error: SessionEstablishment missing mandatory key 'data' (status code 12 CBOR validation error)")
            }
        }
    }
    
    // MARK: - Encoding Tests
    
    @Test("Encoding initialiser constructs SessionEstablishment with valid COSE_Key bytes")
    func encodingInitialiserConstructsSuccessfully() throws {
        // Given: a valid COSE_Key encoded as CBOR bytes
        let coseKey = COSEKey(
            curve: .p256,
            xCoordinate: [UInt8](repeating: 0x01, count: 32),
            yCoordinate: [UInt8](repeating: 0x02, count: 32)
        )
        let eReaderKeyBytes = coseKey.toCBOR(options: CBOROptions()).encode()
        let encryptedData: [UInt8] = [UInt8](repeating: 0xAA, count: 16)
        
        // When
        let sut = try SessionEstablishment(eReaderKeyBytes: eReaderKeyBytes, data: encryptedData)
        
        // Then
        #expect(sut.eReaderKeyBytes == eReaderKeyBytes)
        #expect(sut.data == encryptedData)
        #expect(sut.eReaderKey.curve == .p256)
        #expect(sut.eReaderKey.xCoordinate == [UInt8](repeating: 0x01, count: 32))
        #expect(sut.eReaderKey.yCoordinate == [UInt8](repeating: 0x02, count: 32))
    }
    
    @Test("Encoding initialiser throws when eReaderKeyBytes is not valid CBOR")
    func encodingInitialiserThrowsOnInvalidCBOR() {
        let invalidBytes: [UInt8] = [0xFF, 0xFE]
        let data: [UInt8] = [0x01, 0x02]
        
        #expect(throws: Error.self) {
            try SessionEstablishment(eReaderKeyBytes: invalidBytes, data: data)
        }
    }
    
    @Test("toCBOR produces a CBOR map with exactly 2 keys: eReaderKey and data")
    func toCBORProducesCorrectMapStructure() throws {
        let coseKey = COSEKey(
            curve: .p256,
            xCoordinate: [UInt8](repeating: 0x01, count: 32),
            yCoordinate: [UInt8](repeating: 0x02, count: 32)
        )
        let eReaderKeyBytes = coseKey.toCBOR(options: CBOROptions()).encode()
        let encryptedData: [UInt8] = [UInt8](repeating: 0xAA, count: 16)
        
        let sut = try SessionEstablishment(eReaderKeyBytes: eReaderKeyBytes, data: encryptedData)
        let cbor = sut.toCBOR()
        
        guard case .map(let pairs) = cbor else {
            Issue.record("Expected CBOR map")
            return
        }
        
        #expect(pairs.count == 2)
        
        // Verify eReaderKey is Tag(24, bstr)
        let eReaderKeyValue = try #require(pairs[.utf8String("eReaderKey")])
        guard case .tagged(.encodedCBORDataItem, .byteString(let innerBytes)) = eReaderKeyValue else {
            Issue.record("eReaderKey must be Tag(24, bstr)")
            return
        }
        #expect(innerBytes == eReaderKeyBytes)
        
        // Verify data is bstr
        let dataValue = try #require(pairs[.utf8String("data")])
        guard case .byteString(let dataBytes) = dataValue else {
            Issue.record("data must be a byteString")
            return
        }
        #expect(dataBytes == encryptedData)
    }
    
    @Test("Encoded SessionEstablishment can be decoded back (round-trip)")
    func encodingRoundTrip() throws {
        // Given
        let coseKey = COSEKey(
            curve: .p256,
            xCoordinate: [UInt8](repeating: 0x01, count: 32),
            yCoordinate: [UInt8](repeating: 0x02, count: 32)
        )
        let eReaderKeyBytes = coseKey.toCBOR(options: CBOROptions()).encode()
        let encryptedData: [UInt8] = [UInt8](repeating: 0xAA, count: 16)
        
        // When: encode then decode
        let original = try SessionEstablishment(eReaderKeyBytes: eReaderKeyBytes, data: encryptedData)
        let encodedBytes = Data(original.toCBOR().encode())
        let decoded = try SessionEstablishment(rawData: encodedBytes)
        
        // Then
        #expect(decoded.eReaderKeyBytes == original.eReaderKeyBytes)
        #expect(decoded.data == original.data)
        #expect(decoded.eReaderKey.curve == original.eReaderKey.curve)
        #expect(decoded.eReaderKey.xCoordinate == original.eReaderKey.xCoordinate)
        #expect(decoded.eReaderKey.yCoordinate == original.eReaderKey.yCoordinate)
    }
    
    @Test("Encoded SessionEstablishment first byte indicates CBOR map with 2 items")
    func encodedFirstByteIsMap() throws {
        let coseKey = COSEKey(
            curve: .p256,
            xCoordinate: [UInt8](repeating: 0x01, count: 32),
            yCoordinate: [UInt8](repeating: 0x02, count: 32)
        )
        let eReaderKeyBytes = coseKey.toCBOR(options: CBOROptions()).encode()
        let encryptedData: [UInt8] = [UInt8](repeating: 0xAA, count: 16)
        
        let sut = try SessionEstablishment(eReaderKeyBytes: eReaderKeyBytes, data: encryptedData)
        let bytes = sut.toCBOR().encode()
        
        // Major type 5 (map) with additional info 2 (two pairs): 0b101_00010 = 0xa2
        #expect(bytes[0] == 0xa2)
    }
    
    @Test("Encoded SessionEstablishment handles empty data field")
    func encodedEmptyDataField() throws {
        let coseKey = COSEKey(
            curve: .p256,
            xCoordinate: [UInt8](repeating: 0x01, count: 32),
            yCoordinate: [UInt8](repeating: 0x02, count: 32)
        )
        let eReaderKeyBytes = coseKey.toCBOR(options: CBOROptions()).encode()
        let emptyData: [UInt8] = []
        
        let sut = try SessionEstablishment(eReaderKeyBytes: eReaderKeyBytes, data: emptyData)
        let cbor = sut.toCBOR()
        
        guard case .map(let pairs) = cbor else {
            Issue.record("Expected CBOR map")
            return
        }
        
        let dataValue = try #require(pairs[.utf8String("data")])
        guard case .byteString(let dataBytes) = dataValue else {
            Issue.record("data must be a byteString")
            return
        }
        #expect(dataBytes.isEmpty)
    }
}

// swiftlint:enable line_length
