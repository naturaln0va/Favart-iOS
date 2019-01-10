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

class FileProviderExtension: NSFileProviderExtension {
  private lazy var fileManager = FileManager()
  
  internal lazy var fileCoordinator: NSFileCoordinator = {
    let coordinator = NSFileCoordinator()
    coordinator.purposeIdentifier = NSFileProviderManager.default.providerIdentifier
    return coordinator
  }()
  
  override func item(for identifier: NSFileProviderItemIdentifier) throws -> NSFileProviderItem {
    if identifier == .rootContainer {
      return FileProviderItem.rootItem
    }
    
    guard let item = FileProviderItem(identifier: identifier) else {
      throw NSFileProviderError(.noSuchItem)
    }
    
    return item
  }
  
  override func urlForItem(withPersistentIdentifier identifier: NSFileProviderItemIdentifier) -> URL? {
    do {
      guard let item = try item(for: identifier) as? FileProviderItem else {
        return nil
      }
      
      let manager = NSFileProviderManager.default
      let rootItemURL = manager.documentStorageURL.appendingPathComponent(identifier.rawValue, isDirectory: true)
      
      return rootItemURL.appendingPathComponent(item.filename, isDirectory: item.isDirectory)
    } catch {
      return nil
    }
  }
  
  override func persistentIdentifierForItem(at url: URL) -> NSFileProviderItemIdentifier? {
    let pathComponents = url.pathComponents
    
    // exploit the fact that the path structure has been defined as
    // <base storage directory>/<item identifier>/<item file name> above
    assert(pathComponents.count > 2)
    
    return NSFileProviderItemIdentifier(pathComponents[pathComponents.count - 2])
  }
  
  override func providePlaceholder(at url: URL, completionHandler: @escaping (Error?) -> Void) {
    guard let identifier = persistentIdentifierForItem(at: url), identifier != .rootContainer else {
      completionHandler(NSFileProviderError(.noSuchItem))
      return
    }
    
    do {
      let urlParent = url.deletingLastPathComponent()
      if !fileManager.fileExists(atPath: urlParent.path) { // this was tricky, https://forums.developer.apple.com/thread/89113
        try fileManager.createDirectory(at: urlParent, withIntermediateDirectories: true, attributes: nil)
      }
      
      let fileProviderItem = try item(for: identifier)
      let placeholderURL = NSFileProviderManager.placeholderURL(for: url)
      
      try NSFileProviderManager.writePlaceholder(at: placeholderURL, withMetadata: fileProviderItem)
      completionHandler(nil)
    } catch let error {
      completionHandler(error)
    }
  }
  
  override func startProvidingItem(at url: URL, completionHandler: @escaping ((_ error: Error?) -> Void)) {
    guard let identifier = persistentIdentifierForItem(at: url) else {
      completionHandler(NSFileProviderError(.noSuchItem))
      return
    }
    
    let path = identifier.rawValue.base64Decoded.replacingOccurrences(of: "+", with: "/")
    
    if !fileManager.fileExists(atPath: url.path) {
      NetworkClient.shared.downloadFile(at: path, to: url) { error in
        completionHandler(error)
      }
    } else {
      completionHandler(nil)
    }
  }
  
  override func stopProvidingItem(at url: URL) {
    try? FileManager.default.removeItem(at: url)
    
    providePlaceholder(at: url) { error in
      guard let e = error else {
        return
      }
      
      print("Error providing placeholder: \(e.localizedDescription)")
    }
  }
  
  // MARK: - Enumeration
  
  override func enumerator(for containerItemIdentifier: NSFileProviderItemIdentifier) throws -> NSFileProviderEnumerator {
    if containerItemIdentifier == .rootContainer {
      return FileProviderEnumerator(identifier: containerItemIdentifier)
    } else {
      do {
        if let providerItem = try item(for: containerItemIdentifier) as? FileProviderItem {
          if providerItem.isDirectory {
            return FileProviderEnumerator(identifier: containerItemIdentifier)
          } else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFeatureUnsupportedError, userInfo:[:])
          }
        } else {
          throw NSFileProviderError(.noSuchItem)
        }
      } catch {
        throw NSFileProviderError(.noSuchItem)
      }
    }
  }
  
  override func fetchThumbnails(for itemIdentifiers: [NSFileProviderItemIdentifier], requestedSize size: CGSize, perThumbnailCompletionHandler: @escaping (NSFileProviderItemIdentifier, Data?, Error?) -> Void, completionHandler: @escaping (Error?) -> Void) -> Progress {
    let urlSession = URLSession(configuration: .default)
    let progress = Progress(totalUnitCount: Int64(itemIdentifiers.count))
    
    for identifier in itemIdentifiers {
      let path = identifier.rawValue.base64Decoded.replacingOccurrences(of: "+", with: "/")
      
      guard let requestURL = NetworkClient.buildContentURL(for: path, isPreview: true) else {
        continue
      }
      
      let downloadTask = urlSession.downloadTask(with: requestURL) { tempFileURL, response, error in
        guard !progress.isCancelled else {
          return
        }
        
        var finalError = error
        var processedFileData: Data? = nil
        
        if let fileURL = tempFileURL {
          do {
            processedFileData = try Data(contentsOf: fileURL, options: .alwaysMapped)
          } catch {
            finalError = error
          }
        }
        
        perThumbnailCompletionHandler(identifier, processedFileData, finalError)
        
        guard progress.isFinished else {
          return
        }
        
        DispatchQueue.main.async {
          completionHandler(nil)
        }
      }
      
      progress.addChild(downloadTask.progress, withPendingUnitCount: 1)
      downloadTask.resume()
    }
    
    return progress
  }
}
