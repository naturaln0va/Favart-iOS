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
