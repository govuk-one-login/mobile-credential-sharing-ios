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
        return [UInt8](publicKeyUInt8[1...32])
    }

    var yCoordinate: [UInt8] {
        let publicKeyUInt8 = [UInt8](x963Representation)
        return [UInt8](publicKeyUInt8[33...64])
    }
}
