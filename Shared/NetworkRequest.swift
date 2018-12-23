
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
