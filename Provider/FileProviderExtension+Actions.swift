
import FileProvider

extension FileProviderExtension {
    
    override func setLastUsedDate(_ lastUsedDate: Date?, forItemIdentifier itemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        do {
            guard let item = try item(for: itemIdentifier) as? FileProviderItem else {
                completionHandler(nil, NSFileProviderError(.noSuchItem))
                return
            }
            
            item.lastUsedDate = lastUsedDate
            completionHandler(item, nil)
        }
        catch {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
        }
    }
    
    override func importDocument(at fileURL: URL, toParentItemIdentifier parentItemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        if fileURL.startAccessingSecurityScopedResource() == false {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return
        }
        
        guard let info = FileInfo(url: fileURL) else {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return
        }
        
        let parent = parentItemIdentifier.rawValue.base64Decoded
        let path: String? = parentItemIdentifier == .rootContainer ? nil : parent
        
        let item = FileProviderItem(info: info, parent: path)
        
        completionHandler(item, nil)
        
        var pathComps = [String]()
        if let basePath = path?.replacingOccurrences(of: "+", with: "/") {
            pathComps.append(basePath)
        }
        pathComps.append(info.name)
        let fullPath = pathComps.joined(separator: "/")
        
        fileCoordinator.coordinate(readingItemAt: fileURL, options: .withoutChanges, error: nil) { url in
            guard let fileData = try? Data(contentsOf: url) else {
                return
            }
            
            NetworkClient.shared.uploadFile(from: fileData, to: fullPath) { error in
                self.handleCompletedRequest(with: error, for: item.itemIdentifier)
            }
        }
        
        fileURL.stopAccessingSecurityScopedResource()
    }
    
    override func createDirectory(withName directoryName: String, inParentItemIdentifier parentItemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        let parent = parentItemIdentifier.rawValue.base64Decoded
        let path: String? = parentItemIdentifier == .rootContainer ? nil : parent

        let item = FileProviderItem(name: directoryName, parent: path)
        
        completionHandler(item, nil)
        
        var pathComps = [String]()
        if let basePath = path?.replacingOccurrences(of: "+", with: "/") {
            pathComps.append(basePath)
        }
        pathComps.append(directoryName)
        let fullPath = pathComps.joined(separator: "/")

        NetworkClient.shared.createMedia(at: fullPath) { error in
            self.handleCompletedRequest(with: error, for: item.itemIdentifier)
        }
    }
    
    override func trashItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        do {
            guard let item = try item(for: itemIdentifier) as? FileProviderItem else {
                completionHandler(nil, NSFileProviderError(.noSuchItem))
                return
            }

            item.isTrashed = true
            completionHandler(item, nil)
            
            guard let url = urlForItem(withPersistentIdentifier: itemIdentifier) else {
                completionHandler(nil, NSFileProviderError(.noSuchItem))
                return
            }
            
            try FileManager.default.removeItem(at: url)
            
            NetworkClient.shared.removeMedia(at: itemIdentifier.rawValue.base64Decoded.replacingOccurrences(of: "+", with: "/")) { error in
                self.handleCompletedRequest(with: error, for: item.itemIdentifier)
            }
        }
        catch {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
        }
    }
    
    // MARK: - Helpers
    
    private func handleCompletedRequest(with error: Error?, for identifier: NSFileProviderItemIdentifier) {
        if let e = error {
            print("Error uploading file: \(e.localizedDescription)")
        }
        else {
            NSFileProviderManager.default.signalEnumerator(for: identifier) { error in
                guard let e = error else {
                    return
                }
                
                print("Error signaling file enumerator: \(e.localizedDescription)")
            }
        }
    }
    
}
