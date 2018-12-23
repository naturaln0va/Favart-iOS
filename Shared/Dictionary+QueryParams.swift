
import Foundation

extension Dictionary {
  
  func stringFromHttpParameters() -> String {
    var characterSetForRFC3986: CharacterSet = .urlHostAllowed
    characterSetForRFC3986.insert(charactersIn: ":")
    
    let parameterArray = compactMap { key, value -> String? in
      guard let percentEscapedKey = (key as? String)?.addingPercentEncoding(withAllowedCharacters: characterSetForRFC3986) else {
        print("WARNING! Tried to calculate a query parameter with a non string key.")
        return nil
      }
      
      var value: Any = value
      if let percentEscapedValue = (value as? String)?.addingPercentEncoding(withAllowedCharacters: characterSetForRFC3986) {
        value = percentEscapedValue
      }
      
      return "\(percentEscapedKey)=\(value)"
    }
    
    return parameterArray.joined(separator: "&")
  }
  
}
