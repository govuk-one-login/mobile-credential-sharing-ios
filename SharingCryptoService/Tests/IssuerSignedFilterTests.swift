import Foundation
@testable import SharingCryptoService
import SwiftCBOR
import Testing

// swiftlint:disable type_body_length
@MainActor
@Suite("IssuerSignedFilter Tests")
struct IssuerSignedFilterTests {
    private let sut = IssuerSignedFilter()
    private let standardNameSpace = "org.iso.18013.5.1"
    private let gbNameSpace = "org.iso.18013.5.1.GB"
    private let issuerAuth: [UInt8] = [1, 2, 3, 4, 5]

    // MARK: - Helpers
    private func makeItemBytes(
        identifier: String,
        value: CBOR = .utf8String("test")
    ) -> IssuerSignedItemBytes {
        let rawCBOR: CBOR = .tagged(.encodedCBORDataItem, .byteString(
            CBOR.map([
                .utf8String("digestID"): .unsignedInt(0),
                .utf8String("random"): .byteString([1, 2, 3]),
                .utf8String("elementIdentifier"): .utf8String(identifier),
                .utf8String("elementValue"): value
            ]).encode()
        ))
        return IssuerSignedItemBytes(
            elementIdentifier: identifier,
            elementValue: value,
            rawCBOR: rawCBOR
        )
    }

    private func makeNameSpace(
        name: String,
        elements: [(String, Bool)]
    ) throws -> NameSpace {
        let cbor: CBOR = .map(
            Dictionary(uniqueKeysWithValues: elements.map {
                (.utf8String($0.0), .boolean($0.1))
            })
        )
        return try NameSpace(name: name, cbor: cbor)
    }

    private func makeCredential(
        nameSpaces: [String: [IssuerSignedItemBytes]]
    ) -> ParsedRawCredential {
        ParsedRawCredential(
            docType: "org.iso.18013.5.1.mDL",
            nameSpaces: nameSpaces,
            issuerAuth: issuerAuth
        )
    }

    // MARK: - Single NameSpace Match
    @Test("Retains only requested elements from a single NameSpace")
    func singleNameSpaceFiltering() throws {
        let credential = makeCredential(nameSpaces: [
            standardNameSpace: [
                makeItemBytes(identifier: "family_name", value: .utf8String("Smith")),
                makeItemBytes(identifier: "portrait", value: .byteString([0xFF, 0xD8])),
                makeItemBytes(identifier: "birth_date", value: .utf8String("1990-01-01"))
            ]
        ])
        let requestedNS = try makeNameSpace(
            name: standardNameSpace,
            elements: [("family_name", true), ("portrait", false)]
        )

        let result = try sut.filter(parsedCredential: credential, requestedNameSpaces: [requestedNS])

        #expect(result.nameSpaces.count == 1)
        #expect(result.nameSpaces[standardNameSpace]?.count == 2)
        #expect(result.issuerAuth == issuerAuth)
    }

    // MARK: - Multiple NameSpaces Match
    @Test("Retains elements from multiple NameSpaces independently")
    func multipleNameSpaceFiltering() throws {
        let credential = makeCredential(nameSpaces: [
            standardNameSpace: [
                makeItemBytes(identifier: "family_name", value: .utf8String("Smith")),
                makeItemBytes(identifier: "given_name", value: .utf8String("John")),
                makeItemBytes(identifier: "portrait", value: .byteString([0xFF, 0xD8]))
            ],
            gbNameSpace: [
                makeItemBytes(identifier: "licence_number", value: .utf8String("ABC123")),
                makeItemBytes(identifier: "vehicle_class", value: .utf8String("B"))
            ]
        ])
        let ns1 = try makeNameSpace(name: standardNameSpace, elements: [("family_name", true), ("portrait", false)])
        let ns2 = try makeNameSpace(name: gbNameSpace, elements: [("licence_number", true)])

        let result = try sut.filter(parsedCredential: credential, requestedNameSpaces: [ns1, ns2])

        #expect(result.nameSpaces.count == 2)
        #expect(result.nameSpaces[standardNameSpace]?.count == 2)
        #expect(result.nameSpaces[gbNameSpace]?.count == 1)
    }

    // MARK: - Assembly of IssuerSigned
    @Test("Assembles IssuerSigned with retained items and untouched issuerAuth")
    func assemblyPreservesOriginalBytes() throws {
        let originalItem = makeItemBytes(identifier: "family_name", value: .utf8String("Smith"))
        let credential = makeCredential(nameSpaces: [
            standardNameSpace: [
                originalItem,
                makeItemBytes(identifier: "portrait", value: .byteString([0xFF, 0xD8]))
            ]
        ])
        let requestedNS = try makeNameSpace(name: standardNameSpace, elements: [("family_name", true), ("portrait", false)])

        let result = try sut.filter(parsedCredential: credential, requestedNameSpaces: [requestedNS])

        #expect(result.issuerAuth == issuerAuth)
        let items = try #require(result.nameSpaces[standardNameSpace])
        let item = try #require(items.first(where: { $0.toCBOR() == originalItem.rawCBOR }))
        // The item should use rawCBOR init, preserving original bytes
        #expect(item.toCBOR() == originalItem.rawCBOR)
    }

    // MARK: - No Matching NameSpaces
    @Test("Throws noMatchingNameSpaces when credential has none of the requested NameSpaces")
    func noMatchingNameSpaces() throws {
        let credential = makeCredential(nameSpaces: [
            standardNameSpace: [makeItemBytes(identifier: "family_name")]
        ])
        let requestedNS = try makeNameSpace(name: "org.unknown.namespace", elements: [("family_name", true), ("portrait", false)])

        #expect(throws: IssuerSignedFilterError.noMatchingNameSpaces) {
            try sut.filter(parsedCredential: credential, requestedNameSpaces: [requestedNS])
        }
    }

    // MARK: - Matching NameSpace But No Matching Elements
    @Test("Throws noMatchingAttributes when NameSpace matches but no elements match")
    func noMatchingAttributes() throws {
        let credential = makeCredential(nameSpaces: [
            standardNameSpace: [
                makeItemBytes(identifier: "family_name"),
                makeItemBytes(identifier: "given_name")
            ]
        ])
        let requestedNS = try makeNameSpace(
            name: standardNameSpace,
            elements: [("document_number", true), ("expiry_date", true), ("portrait", false)]
        )

        #expect(throws: IssuerSignedFilterError.noMatchingAttributes) {
            try sut.filter(parsedCredential: credential, requestedNameSpaces: [requestedNS])
        }
    }

    // MARK: - Age Attestation – Closest TRUE
    @Test("Returns closest TRUE age_over where stored age >= requested (22yo, request age_over_19 -> age_over_21)")
    func closestTrueAgeOver() throws {
        let credential = makeCredential(nameSpaces: [
            standardNameSpace: [
                makeItemBytes(identifier: "portrait", value: .byteString([0xFF, 0xD8])),
                makeItemBytes(identifier: "age_over_18", value: .boolean(true)),
                makeItemBytes(identifier: "age_over_21", value: .boolean(true)),
                makeItemBytes(identifier: "age_over_25", value: .boolean(false))
            ]
        ])
        let requestedNS = try makeNameSpace(name: standardNameSpace, elements: [("age_over_19", false), ("portrait", false)])

        let result = try sut.filter(parsedCredential: credential, requestedNameSpaces: [requestedNS])

        let items = try #require(result.nameSpaces[standardNameSpace])
        #expect(items.count == 2)
        // Find the age_over item (not portrait)
        let ageItem = try #require(items.first { item in
            guard case let .tagged(_, .byteString(bytes)) = item.toCBOR(),
                  let decoded = try? CBOR.decode(bytes),
                  case let .map(map) = decoded else { return false }
            return map[.utf8String("elementIdentifier")] != .utf8String("portrait")
        })
        // Verify the retained item is age_over_21 by checking its CBOR encoding
        let cbor = ageItem.toCBOR()
        guard case let .tagged(_, .byteString(bytes)) = cbor,
              let decoded = try? CBOR.decode(bytes),
              case let .map(map) = decoded else {
            Issue.record("Expected tagged CBOR map")
            return
        }
        #expect(map[.utf8String("elementIdentifier")] == .utf8String("age_over_21"))
        #expect(map[.utf8String("elementValue")] == .boolean(true))
    }

    // MARK: - Age Attestation – Fallback to Closest FALSE
    @Test("Falls back to closest FALSE age_over where stored age <= requested (19yo, request age_over_23 -> age_over_21 FALSE)")
    func fallbackClosestFalse() throws {
        let credential = makeCredential(nameSpaces: [
            standardNameSpace: [
                makeItemBytes(identifier: "portrait", value: .byteString([0xFF, 0xD8])),
                makeItemBytes(identifier: "age_over_18", value: .boolean(true)),
                makeItemBytes(identifier: "age_over_21", value: .boolean(false)),
                makeItemBytes(identifier: "age_over_25", value: .boolean(false))
            ]
        ])
        let requestedNS = try makeNameSpace(name: standardNameSpace, elements: [("age_over_23", false), ("portrait", false)])

        let result = try sut.filter(parsedCredential: credential, requestedNameSpaces: [requestedNS])

        let items = try #require(result.nameSpaces[standardNameSpace])
        #expect(items.count == 2)
        let ageItem = try #require(items.first { item in
            guard case let .tagged(_, .byteString(bytes)) = item.toCBOR(),
                  let decoded = try? CBOR.decode(bytes),
                  case let .map(map) = decoded else { return false }
            return map[.utf8String("elementIdentifier")] != .utf8String("portrait")
        })
        let cbor = ageItem.toCBOR()
        guard case let .tagged(_, .byteString(bytes)) = cbor,
              let decoded = try? CBOR.decode(bytes),
              case let .map(map) = decoded else {
            Issue.record("Expected tagged CBOR map")
            return
        }
        #expect(map[.utf8String("elementIdentifier")] == .utf8String("age_over_21"))
        #expect(map[.utf8String("elementValue")] == .boolean(false))
    }

    // MARK: - Age Attestation – No Match (Gap Scenario)

    @Test("Returns no age element when no TRUE >= requested and no FALSE <= requested (19yo, request age_over_20)")
    func noAgeMatch() throws {
        let credential = makeCredential(nameSpaces: [
            standardNameSpace: [
                makeItemBytes(identifier: "family_name", value: .utf8String("Smith")),
                makeItemBytes(identifier: "portrait", value: .byteString([0xFF, 0xD8])),
                makeItemBytes(identifier: "age_over_18", value: .boolean(true)),
                makeItemBytes(identifier: "age_over_21", value: .boolean(false)),
                makeItemBytes(identifier: "age_over_25", value: .boolean(false))
            ]
        ])
        // Request age_over_20, family_name and portrait (so we don't trigger noMatchingAttributes)
        let requestedNS = try makeNameSpace(
            name: standardNameSpace,
            elements: [("age_over_20", false), ("family_name", true), ("portrait", false)]
        )

        let result = try sut.filter(parsedCredential: credential, requestedNameSpaces: [requestedNS])

        let items = try #require(result.nameSpaces[standardNameSpace])
        // family_name and portrait should be retained; age_over_20 has no match
        #expect(items.count == 2)
        // Verify family_name is retained and no age_over item is present
        let hasAgeItem = items.contains { item in
            guard case let .tagged(_, .byteString(bytes)) = item.toCBOR(),
                  let decoded = try? CBOR.decode(bytes),
                  case let .map(map) = decoded,
                  case let .utf8String(id) = map[.utf8String("elementIdentifier")] else { return false }
            return id.hasPrefix("age_over_")
        }
        #expect(hasAgeItem == false)
    }

    // MARK: - Malformed Age Attestation – 1-Digit Dropped
    @Test("Drops age_over request with 1-digit integer (age_over_1)")
    func dropsOneDigitAgeOver() throws {
        let credential = makeCredential(nameSpaces: [
            standardNameSpace: [
                makeItemBytes(identifier: "family_name", value: .utf8String("Smith")),
                makeItemBytes(identifier: "portrait", value: .byteString([0xFF, 0xD8])),
                makeItemBytes(identifier: "age_over_18", value: .boolean(true))
            ]
        ])
        let requestedNS = try makeNameSpace(
            name: standardNameSpace,
            elements: [("age_over_1", false), ("family_name", true), ("portrait", false)]
        )

        let result = try sut.filter(parsedCredential: credential, requestedNameSpaces: [requestedNS])

        let items = try #require(result.nameSpaces[standardNameSpace])
        #expect(items.count == 2)
        // Verify no age_over item is retained (age_over_1 is malformed, should be dropped)
        let hasAgeItem = items.contains { item in
            guard case let .tagged(_, .byteString(bytes)) = item.toCBOR(),
                  let decoded = try? CBOR.decode(bytes),
                  case let .map(map) = decoded,
                  case let .utf8String(id) = map[.utf8String("elementIdentifier")] else { return false }
            return id.hasPrefix("age_over_")
        }
        #expect(hasAgeItem == false)
    }

    // MARK: - Malformed Age Attestation - 3-Digit Dropped
    @Test("Drops age_over request with 3-digit integer (age_over_100)")
    func dropsThreeDigitAgeOver() throws {
        let credential = makeCredential(nameSpaces: [
            standardNameSpace: [
                makeItemBytes(identifier: "family_name", value: .utf8String("Smith")),
                makeItemBytes(identifier: "portrait", value: .byteString([0xFF, 0xD8])),
                makeItemBytes(identifier: "age_over_18", value: .boolean(true))
            ]
        ])
        let requestedNS = try makeNameSpace(
            name: standardNameSpace,
            elements: [("age_over_100", false), ("family_name", true), ("portrait", false)]
        )

        let result = try sut.filter(parsedCredential: credential, requestedNameSpaces: [requestedNS])

        let items = try #require(result.nameSpaces[standardNameSpace])
        #expect(items.count == 2)
        // Verify no age_over item is retained (age_over_100 is malformed, should be dropped)
        let hasAgeItem = items.contains { item in
            guard case let .tagged(_, .byteString(bytes)) = item.toCBOR(),
                  let decoded = try? CBOR.decode(bytes),
                  case let .map(map) = decoded,
                  case let .utf8String(id) = map[.utf8String("elementIdentifier")] else { return false }
            return id.hasPrefix("age_over_")
        }
        #expect(hasAgeItem == false)
    }

    // MARK: - Exceeds Age Over Limit
    @Test("Throws exceededAgeOverLimit when >2 age_over_NN elements requested")
    func throwsWhenMoreThanTwoAgeOverRequested() throws {
        let credential = makeCredential(nameSpaces: [
            standardNameSpace: [
                makeItemBytes(identifier: "age_over_18", value: .boolean(true)),
                makeItemBytes(identifier: "age_over_21", value: .boolean(true)),
                makeItemBytes(identifier: "age_over_25", value: .boolean(false))
            ]
        ])
        let requestedNS = try makeNameSpace(
            name: standardNameSpace,
            elements: [("age_over_15", false), ("age_over_18", false), ("age_over_21", false), ("portrait", false)]
        )

        #expect(throws: IssuerSignedFilterError.exceededAgeOverLimit) {
            try sut.filter(parsedCredential: credential, requestedNameSpaces: [requestedNS])
        }
    }

    // MARK: - Portrait Policy Violation
    @Test("Throws portraitNotRequested when no portrait element is in the request")
    func portraitNotRequested() throws {
        let credential = makeCredential(nameSpaces: [
            standardNameSpace: [
                makeItemBytes(identifier: "family_name", value: .utf8String("Smith")),
                makeItemBytes(identifier: "portrait", value: .byteString([0xFF, 0xD8]))
            ]
        ])
        let requestedNS = try makeNameSpace(
            name: standardNameSpace,
            elements: [("family_name", true)]
        )

        #expect(throws: IssuerSignedFilterError.portraitNotRequested) {
            try sut.filter(parsedCredential: credential, requestedNameSpaces: [requestedNS])
        }
    }
}
// swiftlint:enable type_body_length
