
import Foundation

final class NetworkClient {
    
    static let shared = NetworkClient()
    
    typealias BasicCompletionBlock = (Error?) -> Void
    typealias MediaCompletionBlock = ([FileInfo], Error?) -> Void
    
    private static let baseURLString = "https://pure-lake-51086.herokuapp.com"
    
    private var mediaURLString: String {
        return [NetworkClient.baseURLString, "media"].joined(separator: "/")
    }

    private let underlyingRequestQueue = DispatchQueue(label: "favart.networking")
    
    private lazy var requestsQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.underlyingQueue = underlyingRequestQueue
        queue.qualityOfService = .userInitiated
        return queue
    }()
    
    // MARK: - Error
    
    private func errorFrom(request: NetworkRequest) -> Error? {
        do {
            guard let json = try JSONSerialization.jsonObject(with: request.resultData, options: []) as? [String: String] else {
                return nil
            }
            
            if request.resultStatusCode >= 400 {
                if let errorMessage = json["error"] {
                    return NetworkError.responseError(code: request.resultStatusCode, message: errorMessage)
                }
                else {
                    return NetworkError.unexpectedError
                }
            }
            else {
                return nil
            }
        }
        catch {
            if request.resultStatusCode >= 400 {
                return NetworkError.serverError(code: request.resultStatusCode)
            }
            else {
                return nil
            }
        }
    }
    
    static func buildContentURL(for path: String, isPreview: Bool) -> URL? {
        var pathComps = path.components(separatedBy: "/")
        
        guard let name = pathComps.popLast() else {
            return nil
        }
        
        var getParams = [
            "id": name
        ]
        
        let pathValue = pathComps.joined(separator: "/")
        if !pathValue.isEmpty {
            getParams["path"] = pathValue
        }
        
        let resource = isPreview ? "preview" : "file"
        let finalURLString = String(format: "%@/%@?%@", baseURLString, resource, getParams.stringFromHttpParameters())
        
        return URL(string: finalURLString)
    }
    
    // MARK: - Requests
    
    func getMedia(at path: String?, completion: @escaping MediaCompletionBlock) {
        let request = NetworkRequest(.get, urlString: mediaURLString)
        
        if let path = path {
            request.getParams = [
                "path": path
            ]
        }
        
        request.completionBlock = {
            var items = [FileInfo]()
            var error: Error?
            
            let decoder = JSONDecoder()
            
            if !request.resultData.isEmpty {
                do {
                    items = try decoder.decode([FileInfo].self, from: request.resultData)
                }
                catch let parseError {
                    error = self.errorFrom(request: request) ?? parseError
                }
            }
            
            DispatchQueue.main.async {
                completion(items, error)
            }
        }
        
        requestsQueue.addOperation(request)
    }
    
    func createMedia(at path: String, completion: BasicCompletionBlock?) {
        let request = NetworkRequest(.post, urlString: mediaURLString)
        
        request.formParams = [
            "path": path
        ]

        request.completionBlock = {
            DispatchQueue.main.async {
                completion?(self.errorFrom(request: request))
            }
        }
        
        requestsQueue.addOperation(request)
    }
    
    func removeMedia(at path: String, completion: BasicCompletionBlock?) {
        let request = NetworkRequest(.delete, urlString: mediaURLString)
        
        request.getParams = [
            "path": path
        ]
        
        request.completionBlock = {
            DispatchQueue.main.async {
                completion?(self.errorFrom(request: request))
            }
        }
        
        requestsQueue.addOperation(request)
    }
    
    func downloadFile(at path: String, to destinationURL: URL, completion: BasicCompletionBlock?) {
        guard let requestURL = NetworkClient.buildContentURL(for: path, isPreview: false) else {
            completion?(NetworkError.unexpectedError)
            return
        }
        
        let task = URLSession.shared.downloadTask(with: requestURL) { tempFileURL, response, error in
            var taskError = error
            
            if let fileURL = tempFileURL {
                do {
                    try FileManager.default.copyItem(at: fileURL, to: destinationURL)
                }
                catch {
                    taskError = error
                }
            }
            
            completion?(taskError)
        }
        
        task.resume()
    }
    
    func uploadFile(from data: Data, to path: String, completion: BasicCompletionBlock?) {
        guard let requestURL = NetworkClient.buildContentURL(for: path, isPreview: false) else {
            completion?(NetworkError.unexpectedError)
            return
        }

        var request = URLRequest(url: requestURL)
        request.addValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        request.httpBody = data
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            completion?(error)
        }
        
        task.resume()
    }
    
}
