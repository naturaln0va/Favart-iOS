
import FileProvider

class FileProviderEnumerator: NSObject, NSFileProviderEnumerator {
    
    var enumeratedItemIdentifier: NSFileProviderItemIdentifier
    
    init(enumeratedItemIdentifier: NSFileProviderItemIdentifier) {
        self.enumeratedItemIdentifier = enumeratedItemIdentifier
        super.init()
    }

    func invalidate() {
        // nothing to clean up.
    }

    func enumerateItems(for observer: NSFileProviderEnumerationObserver, startingAt page: NSFileProviderPage) {
        if enumeratedItemIdentifier == .rootContainer {
            NetworkClient.shared.getMedia(at: nil) { items, error in
                if let error = error {
                    observer.finishEnumeratingWithError(error)
                    return
                }
                
                defer {
                    print("Completed the request from the enumerator.")
                    observer.finishEnumerating(upTo: nil)
                }
                
                guard !items.isEmpty else {
                    return
                }
                
                observer.didEnumerate(items.map({ FileProviderItem(info: $0, parent: nil) }))
            }
        }
        else {
            print("WARNING: Failed to handle enumerator for identifier: \(enumeratedItemIdentifier.rawValue)")
        }
        /* TODO:
         - inspect the page to determine whether this is an initial or a follow-up request
         
         If this is an enumerator for a directory, the root container or all directories:
         - perform a server request to fetch directory contents
         If this is an enumerator for the active set:
         - perform a server request to update your local database
         - fetch the active set from your local database
         
         - inform the observer about the items returned by the server (possibly multiple times)
         - inform the observer that you are finished with this page
         */
    }
    
    func enumerateChanges(for observer: NSFileProviderChangeObserver, from anchor: NSFileProviderSyncAnchor) {
        /* TODO:
         - query the server for updates since the passed-in sync anchor
         
         If this is an enumerator for the active set:
         - note the changes in your local database
         
         - inform the observer about item deletions and updates (modifications + insertions)
         - inform the observer when you have finished enumerating up to a subsequent sync anchor
         */
    }

}
