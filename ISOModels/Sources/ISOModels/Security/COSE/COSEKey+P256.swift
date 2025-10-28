import CryptoKit

extension COSEKey {
    public init(publicKey: P256.KeyAgreement.PublicKey) {
        self.init(
            curve: .p256,
            xCoordinate: publicKey.xCoordinate,
            yCoordinate: publicKey.yCoordinate
        )
    }
}

extension P256.KeyAgreement.PublicKey {
    var xCoordinate: [UInt8] {
        let publicKeyUInt8 = [UInt8](x963Representation)
        let xCoordinate = publicKeyUInt8[1...32]
        return [UInt8](xCoordinate)
    }

    var yCoordinate: [UInt8] {
        let publicKeyUInt8 = [UInt8](x963Representation)
        let yCoordinate = publicKeyUInt8[33...64]
        return [UInt8](yCoordinate)
    }

    public init(coseKey: COSEKey) throws {
        try self.init(x963Representation:
            [0x04] + coseKey.xCoordinate + coseKey.yCoordinate
        )
    }
}
