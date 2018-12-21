
import FileProvider

class FileProviderEnumerator: NSObject, NSFileProviderEnumerator {
    
    private let identifier: NSFileProviderItemIdentifier
    
    init(identifier: NSFileProviderItemIdentifier) {
        self.identifier = identifier
        super.init()
    }

    func invalidate() {
        // nothing to clean up.
    }

    func enumerateItems(for observer: NSFileProviderEnumerationObserver, startingAt page: NSFileProviderPage) {
        let path: String?
        let parent: String?
        
        if identifier == .rootContainer {
            path = nil
            parent = nil
        }
        else {
            path = identifier.rawValue.base64Decoded.replacingOccurrences(of: "+", with: "/")
            parent = identifier.rawValue.base64Decoded
        }
        
        NetworkClient.shared.getMedia(at: path) { items, error in
            if let error = error {
                observer.finishEnumeratingWithError(error)
                return
            }
            
            guard !items.isEmpty else {
                observer.finishEnumerating(upTo: nil)
                return
            }
            
            let providerItems = items.map({ FileProviderItem(info: $0, parent: parent) })
            observer.didEnumerate(providerItems)
            
            observer.finishEnumerating(upTo: nil)
        }
    }
    
}
