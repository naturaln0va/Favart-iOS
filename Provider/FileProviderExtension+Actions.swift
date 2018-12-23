
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
        
        fileCoordinator.coordinate(readingItemAt: fileURL, options: .withoutChanges, error: nil) { url in
            let basePath = path?.replacingOccurrences(of: "+", with: "/") ?? ""
            let fullPath = [basePath, info.name].joined(separator: "/")
            
            guard let fileData = try? Data(contentsOf: url) else {
                return
            }
            
            NetworkClient.shared.uploadFile(from: fileData, to: fullPath) { error in
                if let e = error {
                    print("Error uploading file: \(e.localizedDescription)")
                }
                else {
                    NSFileProviderManager.default.signalEnumerator(for: item.itemIdentifier) { error in
                        guard let e = error else {
                            return
                        }
                        
                        print("Error signaling file enumerator: \(e.localizedDescription)")
                    }
                }
            }
        }
        
        fileURL.stopAccessingSecurityScopedResource()
    }
    
}
