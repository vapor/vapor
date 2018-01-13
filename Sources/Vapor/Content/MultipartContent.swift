import Multipart
import HTTP
import Foundation

extension MultipartForm: Content {
    /// Encodes a MultipartForm as Data
    public func encode(to encoder: Encoder) throws {
        try MultipartSerializer(form: self).serialize().encode(to: encoder)
    }
    
    /// Creates a new MultipartForm from decoded Data
    public init(from decoder: Decoder) throws {
        let data = try Data(from: decoder)
        
        self = try MultipartParser(data: data, boundary: MultipartParser.boundary(for: data)).parse()
    }
    
    /// See Content.defaultMediaType
    public static var defaultMediaType: MediaType {
        return .multipart
    }
    
    /// See RequestEncodable.encode
    public func encode(to req: inout Request) throws -> Future<Void> {
        guard let boundary = String(bytes: self.boundary, encoding: .utf8) else {
            throw VaporError(identifier: "boundary-utf8", reason: "The Multipart boundary was not valid UTF-8")
        }
        
        let data = MultipartSerializer(form: self).serialize()
        req.body = HTTPBody(data)
        req.headers[.contentType] = "multipart/form-data; boundary=" + boundary
        
        return .done
    }
    
    /// See ResponseEncodable.encode
    public func encode(to res: inout Response, for req: Request) throws -> Future<Void> {
        guard let boundary = String(bytes: self.boundary, encoding: .utf8) else {
            throw VaporError(identifier: "boundary-utf8", reason: "The Multipart boundary was not valid UTF-8")
        }
        
        let data = MultipartSerializer(form: self).serialize()
        res.body = HTTPBody(data)
        res.headers[.contentType] = "multipart/form-data; boundary=" + boundary
        
        return .done
    }
    
    /// See RequestDecodable.decode
    public static func decode(from req: Request) throws -> Future<MultipartForm> {
        guard let boundary = req.headers[.contentType, "boundary"] else {
            throw VaporError(identifier: "boundary-utf8", reason: "The Multipart boundary was found in the headers")
        }
        
        return req.body.makeData(max: 1_000_000).map(to: MultipartForm.self) { data in
            return try MultipartParser(data: data, boundary: Array(boundary.utf8)).parse()
        }
    }
    
    /// See ResponseDecodable.decode
    public static func decode(from res: Response, for req: Request) throws -> Future<MultipartForm> {
        guard let boundary = req.headers[.contentType, "boundary"] else {
            throw VaporError(identifier: "boundary-utf8", reason: "The Multipart boundary was found in the headers")
        }
        
        return req.body.makeData(max: 1_000_000).map(to: MultipartForm.self) { data in
            return try MultipartParser(data: data, boundary: Array(boundary.utf8)).parse()
        }
    }
}
