import ExchangeFormat
import Testing

struct ExchangeFormatTests {
    @Test("ExchangeFormat can be imported by a consumer")
    func moduleCanBeImported() {
        #expect(Bool(true))
    }
}
