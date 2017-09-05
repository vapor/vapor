import Foundation
import Files

public struct Multipart {
    public struct Part {
        public var data: Data
        internal let key: String?
        public var headers: Headers
        
        init(data: Data, key: String?, headers: Headers) {
            self.data = data
            self.key = key
            self.headers = headers
        }
    }
    
    public subscript(name: String) -> String? {
        return try? self.getString(forName: name)
    }
    
    public subscript(fileFor name: String) -> File? {
        return try? self.getFile(forName: name)
    }
    
    public subscript(filesFor name: String) -> [File] {
        return self.getFiles(forName: name)
    }
    
    public func getString(forName name: String) throws -> String {
        for part in parts where part.key == name {
            guard let string = String(bytes: part.data, encoding: .utf8) else {
                throw Error(identifier: "http:multipart:invalid-utf8-string", reason: "The part could not be deserialized as UTF-8")
            }
            
            return string
        }
        
        throw Error(identifier: "http:multipart:no-part", reason: "There is no part with the provided name")
    }
    
    public func getFile(forName name: String) throws -> File {
        for part in parts where part.key == name {
            let name = part.headers[.contentDisposition, "filename"] ?? ""
            return File(named: name, data: part.data)
        }
        
        throw Error(identifier: "http:multipart:no-part", reason: "There is no part with the provided name")
    }
    
    public func getFiles(forName name: String) -> [File] {
        return parts.flatMap { part in
            guard part.key == name else {
                return nil
            }
            
            let name = part.headers[.contentDisposition, "filename"] ?? ""
            return File(named: name, data: part.data)
        }
    }
    
    public var parts: [Part]
}
