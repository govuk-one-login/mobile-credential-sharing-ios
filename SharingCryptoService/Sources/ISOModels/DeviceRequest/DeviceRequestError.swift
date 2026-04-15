import Foundation

public enum DeviceRequestError: LocalizedError {
    case dataIsNotValidCBOR
    case deviceRequestWasIncorrectlyStructured
    case docRequestWasEmpty
    case docRequestWasIncorrectlyStructured
    case itemsRequestWasIncorrectlyStructured
    case nameSpaceWasIncorrectlyStructured
    case unsupportedDocumentType
    
    public var errorDescription: String? {
        return "\(self): status code \(self.statusCode)"
    }
    
    public var statusCode: SessionDataStatusCode {
        switch self {
        case .dataIsNotValidCBOR:
            return .cborDecoding
        case .deviceRequestWasIncorrectlyStructured,
                .docRequestWasEmpty,
                .docRequestWasIncorrectlyStructured,
                .itemsRequestWasIncorrectlyStructured,
                .nameSpaceWasIncorrectlyStructured,
                .unsupportedDocumentType:
            return .sessionTermination
        }
    }
}
