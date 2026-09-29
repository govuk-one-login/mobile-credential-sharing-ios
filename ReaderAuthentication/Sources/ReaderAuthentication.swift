// The ReaderAuthentication component.
//
// The component is reachable by SDK orchestration only. It is NOT re-exported by the
// Host-facing `CredentialSharing` facade, so no ReaderAuthentication type is reachable
// from the Host App.
//
// Its permitted in-SDK dependencies are `CoseVerification` and `ExchangeFormat`.
