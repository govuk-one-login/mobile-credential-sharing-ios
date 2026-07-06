import Foundation

extension VerifiedRequestObject {
    /// Decodes a verified JWT's header and payload bytes into a `VerifiedRequestObject`.
    ///
    /// This keeps OID4VP request-object decoding inside the validation module: the crypto layer
    /// verifies the signature and returns raw bytes (`VerifiedJWT`), and the orchestrator forwards
    /// those bytes here without interpreting them. String and object claims are read directly;
    /// `dcql_query` and `client_metadata` are re-serialised to JSON `Data` for downstream decoding.
    public init(
        headerData: Data,
        payloadData: Data,
        leafCertificateSANs: [String]
    ) throws(ValidationError) {
        guard let header = try? JSONSerialization.jsonObject(with: headerData) as? [String: Any] else {
            throw .malformedRequestObjectHeader
        }

        guard let payload = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any] else {
            throw .malformedRequestObjectPayload
        }

        self.init(
            headerTyp: header["typ"] as? String,
            aud: payload["aud"] as? String,
            clientID: payload["client_id"] as? String,
            responseType: payload["response_type"] as? String,
            responseMode: payload["response_mode"] as? String,
            responseURI: payload["response_uri"] as? String,
            redirectURI: payload["redirect_uri"] as? String,
            nonce: payload["nonce"] as? String,
            state: payload["state"] as? String,
            dcqlQueryData: Self.serialise(payload["dcql_query"]),
            clientMetadataData: Self.serialise(payload["client_metadata"]),
            leafCertificateSANs: leafCertificateSANs
        )
    }

    /// Re-serialises a JSON sub-object back to `Data`, or returns `nil` when the claim is absent.
    private static func serialise(_ value: Any?) -> Data? {
        guard let value, JSONSerialization.isValidJSONObject(value) else {
            return nil
        }
        return try? JSONSerialization.data(withJSONObject: value)
    }
}
