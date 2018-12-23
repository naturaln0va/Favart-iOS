
import FileProvider

class FileProviderItem: NSObject, NSFileProviderItem {
  let name: String
  let parent: String?
  let size: Int?
  
  var lastUsedDate: Date?
  var isTrashed: Bool = false
  
  var isDirectory: Bool {
    return name.components(separatedBy: ".").count == 1
  }
  
  static var rootItem: FileProviderItem {
    return FileProviderItem(name: "", parent: nil)
  }
  
  init(name: String, parent: String?) {
    self.name = name
    self.parent = parent
    size = nil
    lastUsedDate = Date()
  }
  
  init(info: FileInfo, parent: String?) {
    name = info.name
    self.parent = parent
    size = info.size
    lastUsedDate = Date()
  }
  
  convenience init?(identifier: NSFileProviderItemIdentifier) {
    let decodedIdentifier = identifier.rawValue.base64Decoded
    guard decodedIdentifier != identifier.rawValue else {
      return nil
    }
    
    var comps = decodedIdentifier.components(separatedBy: "+")
    
    guard let name = comps.popLast() else {
      return nil
    }
    
    let parent = comps.isEmpty ? nil : comps.joined(separator: "+")
    self.init(name: name, parent: parent)
  }
  
}

extension FileProviderItem {
  
  var itemIdentifier: NSFileProviderItemIdentifier {
    guard !name.isEmpty else {
      return .rootContainer
    }
    
    var comps = [String]()
    
    if let encodedParent = parent {
      comps.append(encodedParent)
    }
    comps.append(name)
    
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
    return name
  }
  
  var typeIdentifier: String {
    let comps = name.components(separatedBy: ".")
    
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
    var version = lastUsedDate?.timeIntervalSince1970 ?? 1
    return Data(bytes: &version, count: MemoryLayout.size(ofValue: version))
  }
}
