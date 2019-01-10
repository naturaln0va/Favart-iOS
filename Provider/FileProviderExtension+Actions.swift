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

extension FileProviderExtension {
  override func setLastUsedDate(_ lastUsedDate: Date?, forItemIdentifier itemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
    do {
      guard let item = try item(for: itemIdentifier) as? FileProviderItem else {
        completionHandler(nil, NSFileProviderError(.noSuchItem))
        return
      }
      
      item.lastUsedDate = lastUsedDate
      completionHandler(item, nil)
    } catch {
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
    } catch {
      completionHandler(nil, NSFileProviderError(.noSuchItem))
    }
  }
  
  // MARK: - Helpers
  
  private func handleCompletedRequest(with error: Error?, for identifier: NSFileProviderItemIdentifier) {
    if let e = error {
      print("Error uploading file: \(e.localizedDescription)")
    } else {
      NSFileProviderManager.default.signalEnumerator(for: identifier) { error in
        guard let e = error else {
          return
        }
        
        print("Error signaling file enumerator: \(e.localizedDescription)")
      }
    }
  }
}
