
import Foundation

enum NetworkError: Error {
    case unexpectedError
    case serverError(code: Int)
    case responseError(code: Int, message: String?)
}

extension NetworkError: LocalizedError {
    
    var errorDescription: String? {
        switch self {
        case .unexpectedError:
            return NSLocalizedString("UNEXPECTEDERROR", comment: "")
        case .serverError(let code):
            let statusMessage = HTTPURLResponse.localizedString(forStatusCode: code)
            return "\(code): \(statusMessage)"
        case .responseError(let code, let message):
            if let serverMessage = message {
                return NSLocalizedString(serverMessage, comment: "Server Error Code")
            }
            else {
                return "\(code): \(HTTPURLResponse.localizedString(forStatusCode: code))"
            }
        }
    }
    
}
