
import Foundation

struct FileInfo: Codable {
    
    let name: String
    let size: Int
    
    init?(url: URL) {
        do {
            let values = try url.resourceValues(
                forKeys: [.nameKey, .fileSizeKey]
            )
            
            guard let fileName = values.name, let size = values.fileSize, let type = fileName.components(separatedBy: ".").last else {
                return nil
            }
            
            self.size = size
            name = [UUID().uuidString, type].joined(separator: ".")
        }
        catch {
            return nil
        }
    }
    
}
