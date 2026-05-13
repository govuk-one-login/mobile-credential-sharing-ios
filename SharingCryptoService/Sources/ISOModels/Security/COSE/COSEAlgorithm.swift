import SwiftCBOR

enum COSEHeader: UInt64 {
    case algorithm = 1
}

enum COSEAlgorithm: UInt64 {
    /// ES256 : CBOR .negativeInt(6) encodes the value -7
    case es256 = 6
}

extension COSEAlgorithm {
    var protectedHeaderCBOR: CBOR {
        .map([.unsignedInt(COSEHeader.algorithm.rawValue): .negativeInt(rawValue)])
    }
}
