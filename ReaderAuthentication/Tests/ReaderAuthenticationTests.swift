@testable import ReaderAuthentication
import Testing

// The ReaderAuthentication component is created empty in Story R0. This test target
// exists to prove the module and its test target compile as SDK-internal components.
// Behavioural tests arrive with the signing (R1), request-building (R3), and
// verification (R4–R6) stories.
struct ReaderAuthenticationTests {
    @Test
    func moduleCompiles() {
        // The module builds and is importable within the SDK.
        #expect(Bool(true))
    }
}
