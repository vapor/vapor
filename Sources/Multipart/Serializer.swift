import HTTP
import Foundation

/// Serializes a multipart form into a body
public final class MultipartSerializer {
    /// The form being serialized
    let form: MultipartForm
    
    /// Creates a new MultipartSerializer
    public init(form: MultipartForm) {
        self.form = form
    }
    
    /// Serializes the form
    public func serialize() -> Data {
        var body = Data()
        var reserved = 0
        
        for part in form.parts {
            reserved += part.data.count
        }
        
        body.reserveCapacity(reserved + 512)
        let boundary =  [.hyphen, .hyphen] + form.boundary
        
        for part in form.parts {
            body.append(contentsOf: boundary)
            body.append(contentsOf: [.carriageReturn, .newLine])
            
            part.headers.withByteBuffer { buffer in
                body.append(buffer)
            }
            
            body.append(contentsOf: [.carriageReturn, .newLine])
            body.append(part.data)
            body.append(contentsOf: [.carriageReturn, .newLine])
        }
        
        body.append(contentsOf: boundary)
        body.append(contentsOf: [.hyphen, .hyphen, .carriageReturn, .newLine])
        
        return body
    }
}
