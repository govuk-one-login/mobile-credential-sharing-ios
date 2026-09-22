// The ReaderAuthentication component.
//
// This module is an SDK-internal foundation created in Story R0. It intentionally
// exposes no operations, request values, or failure types yet:
//   - R1 adds the signing types.
//   - R3 adds `buildAuthenticatedDeviceRequest`.
//   - R4–R6 add the verification contract.
//
// The component is reachable by SDK orchestration only. It is NOT re-exported by the
// Host-facing `CredentialSharing` facade, so no ReaderAuthentication type is reachable
// from the Host App.
//
// Its only permitted in-SDK dependency is `CoseVerification`.
