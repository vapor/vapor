import Foundation
import HTTP

/// A single part
///
/// [Learn More →](https://docs.vapor.codes/3.0/http/multipart/#reading-forms)
public struct Part {
    /// The part's containing data
    public var data: Data
    
    /// The associated form key/name, if any
    internal let key: String?
    
    /// The headers metadata
    public var headers: HTTPHeaders
    
    /// Creates a new part
    init(data: Data, key: String?, headers: HTTPHeaders) {
        self.data = data
        self.key = key
        self.headers = headers
    }
}

/// A Multipart, commonly used in HTTP Forms and SMTP emails
///
/// [Learn More →](https://docs.vapor.codes/3.0/http/multipart/#reading-forms)
public struct Form {
    /// All raw parts in this multipart
    public var parts: [Part]
    
    /// Gets the `String` associated with the `name`. Throws an error if there is no `String` encoded as UTF-8
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/http/multipart/#reading-forms)
    public func getString(forName name: String) throws -> String {
        for part in parts where part.key == name {
            guard let string = String(bytes: part.data, encoding: .utf8) else {
                throw MultipartError(identifier: "multipart:invalid-utf8-string", reason: "The part could not be deserialized as UTF-8")
            }
            
            return string
        }
        
        throw MultipartError(identifier: "multipart:no-part", reason: "There is no part with the provided name")
    }
    
    /// Gets the `File` associated with the `name`. Throws an error if there is no `File` encoded as UTF-8
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/http/multipart/#reading-forms)
    public func getFile(forName name: String) throws -> Data {
        for part in parts where part.key == name {
            return part.data
        }
        
        throw MultipartError(identifier: "multipart:no-part", reason: "There is no part with the provided name")
    }
    
    /// Gets all `File`s associated with the `name`.
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/http/multipart/#reading-forms)
    public func getFiles(forName name: String) -> [Data] {
        return parts.flatMap { part in
            guard part.key == name else {
                return nil
            }
            
            return part.data
        }
    }
}
