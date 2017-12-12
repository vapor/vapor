import HTTP
import Foundation

/// Any entity that is initializable by a Multipart Part
public protocol MultipartInitializable {
    init(part: Part) throws
}

/// A basic Multipart file
public struct MultipartFile: MultipartInitializable {
    /// The uploaded file's name
    public var filename: String?
    
    /// The uploaded file's content type
    public var mimeType: MediaType?
    
    /// The file data
    public var data: Data
    
    /// Creates a new Multipart file
    public init(part: Part) throws {
        self.mimeType = MediaType(string: part.headers[.contentType] ?? "")
        self.filename = part.headers[.contentDisposition, "filename"]
        self.data = part.data
    }
}
