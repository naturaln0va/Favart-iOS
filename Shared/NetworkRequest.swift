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

import Foundation

final class NetworkRequest: Operation {
  enum State: String {
    case ready, executing, finished
    
    fileprivate var keyPath: String {
      return "is" + rawValue.capitalized
    }
  }
  
  enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
  }
  
  private(set) var state = State.ready {
    willSet {
      willChangeValue(forKey: newValue.keyPath)
      willChangeValue(forKey: state.keyPath)
    }
    didSet {
      didChangeValue(forKey: oldValue.keyPath)
      didChangeValue(forKey: state.keyPath)
    }
  }
  
  var operating: Bool {
    return state != .finished
  }
  
  let method: HTTPMethod
  var urlString: String
  
  var debug = false
  
  var resultData = Data()
  var resultStatusCode: Int = NSNotFound
  var resultError: Error?
  
  var getParams: [String: Any] = [:]
  var jsonParams: [String: Any] = [:]
  var formParams: [String: Any] = [:]
  var sessionConfiguration: URLSessionConfiguration = .default
  
  private var sessionTask: URLSessionTask?
  private var internalURLSession: URLSession {
    return URLSession(configuration: sessionConfiguration, delegate: self, delegateQueue: nil)
  }
  
  init(_ method: HTTPMethod, urlString: String) {
    self.method = method
    self.urlString = urlString
    super.init()
  }
  
  private func log(info: String) {
    if debug {
      print("<\(method.rawValue) \(urlString)> \(info).")
    }
  }
}

// MARK: - NSOperation Overrides

extension NetworkRequest {
  override var isReady: Bool {
    return super.isReady && state == .ready
  }
  
  override var isExecuting: Bool {
    return state == .executing
  }
  
  override var isFinished: Bool {
    return state == .finished
  }
  
  override var isAsynchronous: Bool {
    return true
  }
  
  override func start() {
    if isCancelled {
      state = .finished
      return
    }
    
    if !getParams.isEmpty {
      let parameterString = getParams.stringFromHttpParameters()
      urlString += "?" + parameterString
    }
    
    guard let url = URL(string: urlString) else {
      fatalError("A url string is required to make a network request.")
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = method.rawValue
    
    if let jsonPostData = try? JSONSerialization.data(withJSONObject: jsonParams, options: []), !jsonParams.isEmpty {
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.setValue("\(jsonPostData.count)", forHTTPHeaderField: "Content-Length")
      request.httpBody = jsonPostData
      log(info: "JSON Post Body: \(jsonParams)")
    } else if !formParams.isEmpty {
      let formValue = formParams.stringFromHttpParameters()
      
      request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
      request.setValue("\(formValue.count)", forHTTPHeaderField: "Content-Length")
      request.httpBody = formValue.data(using: .utf8)
      
      log(info: "Form Post Body: \(formParams)")
    }
    
    sessionTask = internalURLSession.dataTask(with: request)
    sessionTask?.resume()
    state = .executing
  }
  
  override func cancel() {
    sessionTask?.cancel()
    state = .finished
  }
}

// MARK: - NSURLSession Delegate

extension NetworkRequest: URLSessionDataDelegate {
  func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
    if isCancelled {
      state = .finished
      sessionTask?.cancel()
      return
    }
    
    if let httpResponse = response as? HTTPURLResponse {
      resultStatusCode = httpResponse.statusCode
      log(info: "Code \(httpResponse.statusCode): \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))")
      
      if httpResponse.statusCode == 204 {
        log(info: "Canceling task because of the HTTP status code, \(httpResponse.statusCode)")
        state = .finished
        sessionTask?.cancel()
        completionHandler(.cancel)
      }
    }
    
    completionHandler(.allow)
  }
  
  func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
    if isCancelled {
      state = .finished
      sessionTask?.cancel()
      return
    }
    
    resultData.append(data)
  }
  
  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    if isCancelled {
      state = .finished
      sessionTask?.cancel()
      return
    }
    
    if let e = error {
      log(info: "Task failed with error: \(e.localizedDescription)")
      resultError = e
      state = .finished
    } else {
      log(info: "Task succeeded\(Thread.isMainThread ? " on the main thread" : ""), recieved: \(resultData.count) bytes")
    }
    
    if let json = try? JSONSerialization.jsonObject(with: resultData, options: []) {
      log(info: "Result JSON object: \(json)")
    }
    
    state = .finished
  }
}
