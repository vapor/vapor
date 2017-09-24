import Foundation
import Files

/// A single part
public struct Part {
    /// The part's containing data
    public var data: Data
    
    /// The associated form key/name, if any
    internal let key: String?
    
    /// The headers metadata
    public var headers: Headers
    
    /// Creates a new part
    init(data: Data, key: String?, headers: Headers) {
        self.data = data
        self.key = key
        self.headers = headers
    }
}

/// A Multipart, commonly used in HTTP Forms and SMTP emails
public struct Form {
    /// All raw parts in this multipart
    public var parts: [Part]
    
    /// Gets the `String` associated with the `name`. Throws an error if there is no `String` encoded as UTF-8
    public func getString(forName name: String) throws -> String {
        for part in parts where part.key == name {
            guard let string = String(bytes: part.data, encoding: .utf8) else {
                throw Error(identifier: "multipart:invalid-utf8-string", reason: "The part could not be deserialized as UTF-8")
            }
            
            return string
        }
        
        throw Error(identifier: "multipart:no-part", reason: "There is no part with the provided name")
    }
    
    /// Gets the `File` associated with the `name`. Throws an error if there is no `File` encoded as UTF-8
    public func getFile(forName name: String) throws -> File {
        for part in parts where part.key == name {
            let name = part.headers[.contentDisposition, "filename"] ?? ""
            return File(named: name, data: part.data)
        }
        
        throw Error(identifier: "multipart:no-part", reason: "There is no part with the provided name")
    }
    
    /// Gets all `File`s associated with the `name`.
    public func getFiles(forName name: String) -> [File] {
        return parts.flatMap { part in
            guard part.key == name else {
                return nil
            }
            
            let name = part.headers[.contentDisposition, "filename"] ?? ""
            return File(named: name, data: part.data)
        }
    }
}
