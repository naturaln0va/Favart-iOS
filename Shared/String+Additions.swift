
import Foundation

extension String {
    
    var base64Encoded: String {
        return data(using: .utf8)?.base64EncodedString() ?? self
    }
    
}
