import Foundation

enum DeviceRequestError: LocalizedError {
    case dataIsNotValidCBOR
    case deviceRequestWasIncorrectlyStructured
    case docRequestWasEmpty
    case docRequestWasIncorrectlyStructured
    case itemsRequestWasIncorrectlyStructured
    case nameSpaceWasIncorrectlyStructured
    case unsupportedDocumentType
    
    var errorDescription: String? {
        return "\(self): status code \(self.statusCode)"
    }
    
    var statusCode: Int {
        switch self {
        case .dataIsNotValidCBOR:
            return 11
        case .deviceRequestWasIncorrectlyStructured,
                .docRequestWasEmpty,
                .docRequestWasIncorrectlyStructured,
                .itemsRequestWasIncorrectlyStructured,
                .nameSpaceWasIncorrectlyStructured,
                .unsupportedDocumentType:
            return 20
        }
    }
}
