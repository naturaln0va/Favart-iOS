
import Foundation

final class NetworkClient {
    
    static let shared = NetworkClient()
    
    typealias BasicCompletionBlock = (Error?) -> Void
    typealias MediaCompletionBlock = ([FileInfo], Error?) -> Void
    
    private let baseURLString = "http://localhost:8080"
    
    private var mediaURLString: String {
        return [baseURLString, "media"].joined(separator: "/")
    }
    private var fileURLString: String {
        return [baseURLString, "file"].joined(separator: "/")
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
            
            do {
                items = try decoder.decode([FileInfo].self, from: request.resultData)
            }
            catch let parseError {
                error = self.errorFrom(request: request) ?? parseError
            }
            
            DispatchQueue.main.async {
                completion(items, error)
            }
        }
        
        requestsQueue.addOperation(request)
    }
    
    func downloadFile(at path: String, to destinationURL: URL, completion: BasicCompletionBlock?) {
        var pathComps = path.components(separatedBy: "/")
        
        guard let name = pathComps.popLast() else {
            completion?(NetworkError.unexpectedError)
            return
        }
        
        var getParams = [
            "id": name
        ]

        let pathValue = pathComps.joined(separator: "/")
        if !pathValue.isEmpty {
            getParams["path"] = pathValue
        }

        let finalURLString = fileURLString + "?" + getParams.stringFromHttpParameters()
        
        guard let requestURL = URL(string: finalURLString) else {
            completion?(NetworkError.unexpectedError)
            return
        }
        
        let task = URLSession.shared.downloadTask(with: requestURL) { url, resp, error in
            var taskError = error
            
            if let url = url {
                do {
                    try FileManager.default.copyItem(at: url, to: destinationURL)
                }
                catch {
                    taskError = error
                }
            }
            
            completion?(taskError)
        }
        
        task.resume()
    }
    
}
