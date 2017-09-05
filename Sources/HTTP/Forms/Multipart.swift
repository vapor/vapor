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
    
    public func getString(named name: String) throws -> String {
        for part in parts where part.key == name {
            guard let string = String(bytes: part.data, encoding: .utf8) else {
                throw Error(identifier: "http:multipart:invalid-utf8-string", reason: "The part could not be deserialized as UTF-8")
            }
            
            return string
        }
        
        throw Error(identifier: "http:multipart:no-part", reason: "There is no part with the provided name")
    }
    
    public func getFile(named name: String) throws -> File? {
        for part in parts where part.key == name {
//            return File
            
        }
        
        throw Error(identifier: "http:multipart:no-part", reason: "There is no part with the provided name")
    }
    
    public var parts: [Part]
}
