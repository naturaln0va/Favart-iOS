/// Copyright (c) 2018 Razeware LLC
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
///
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

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
  
  var capabilities: NSFileProviderItemCapabilities {
    let baseCapabilities: NSFileProviderItemCapabilities = [
      .allowsReading,
      .allowsTrashing,
      ]
    
    if isDirectory {
      return baseCapabilities.union(
        [.allowsContentEnumerating, .allowsAddingSubItems]
      )
    } else {
      return baseCapabilities
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
