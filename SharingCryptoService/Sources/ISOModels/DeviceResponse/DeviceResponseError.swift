import Foundation

public enum DeviceResponseError: LocalizedError, Equatable {
    /// AC1: Input data is nil or zero-length
    case invalidInput
    /// AC2 & AC7: CBOR structure is malformed, Tag 24 contains invalid inner byte string,
    /// or a Document within the documents array is malformed
    case cborDecodingError
    /// AC5: Holder reported a DeviceRequest processing error (status 10, 11, or 12)
    case deviceRequestProcessingError(status: UInt64)
    /// AC6: Status is 0 but the documents array is empty or missing
    case documentNotReturned

    public var errorDescription: String? {
        switch self {
        case .invalidInput:
            return "DeviceResponse parsing halted: invalid input"
        case .cborDecodingError:
            return "DeviceResponse parsing halted: CBOR decoding error"
        case .deviceRequestProcessingError(let status):
            return "DeviceRequest processing error: status code \(status)"
        case .documentNotReturned:
            return "Document not returned error: status code 0"
        }
    }
}
