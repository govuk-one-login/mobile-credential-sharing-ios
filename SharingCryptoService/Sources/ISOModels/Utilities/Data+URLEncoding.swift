import Foundation

extension Data {
    public init?(base64URLEncoded string: String) {
        let base64String = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let padding = String(repeating: "=", count: string.count % 4)

        guard let data = Data(base64Encoded: base64String + padding) else {
            return nil
        }
        self = data
    }

    public func base64URLEncodedString() -> String {
        self.base64EncodedString()
            .replacingOccurrences(of: "=", with: "")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
    }
}
