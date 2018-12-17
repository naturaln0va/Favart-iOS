
import FileProvider

class FileProviderItem: NSObject, NSFileProviderItem {
    
    let file: String
    let parent: String?
    let size: Int?
    
    init(file: String, parent: String?) {
        self.file = file
        self.parent = parent
        size = nil
    }
    
    init(info: FileInfo, parent: String?) {
        file = info.name
        self.parent = parent
        size = info.size
    }
    
}

extension FileProviderItem {
    
    var itemIdentifier: NSFileProviderItemIdentifier {
        var comps = [file]
        
        if let parent = parent {
            comps.insert(parent, at: 0)
        }
        
        let key = comps.joined(separator: "+")
        return NSFileProviderItemIdentifier(key.base64Encoded)
    }
    
    var parentItemIdentifier: NSFileProviderItemIdentifier {
        guard let parent = parent else {
            return .rootContainer
        }
        
        return NSFileProviderItemIdentifier(parent.base64Encoded)
    }
    
    var capabilities: NSFileProviderItemCapabilities {
        return .allowsAll
    }
    
    var filename: String {
        return file
    }
    
    var typeIdentifier: String {
        let comps = file.components(separatedBy: ".")
        
        if comps.count == 1 {
            return "public.folder"
        }
        
        guard let fileType = comps.last, !fileType.isEmpty else {
            return "unknown"
        }
        
        switch fileType {
        case "png":
            return "public.png"
        case "jpg", "jpeg":
            return "public.jpeg"
        default:
            return "public.image"
        }
    }
    
    var documentSize: NSNumber? {
        guard let size = size else {
            return nil
        }
        
        return NSNumber(value: size)
    }
    
    var versionIdentifier: Data? {
        var initialVersion = 1
        return Data(bytes: &initialVersion, count: MemoryLayout.size(ofValue: initialVersion))
    }
    
}
