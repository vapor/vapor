import Core
import Service
import HTTP

/// An HTTP Request with a type-safe body
public final class TypeSafeRequest<Content: Codable> : RequestRepresentable {
    /// HTTP requests have a method, like GET or POST
    public var method: Method
    
    /// This is usually just a path like `/foo` but
    /// may be a full URI in the case of a proxy
    public var uri: URI
    
    /// See `Message.version`
    public var version: Version
    
    /// See `Message.headers`
    public var headers: Headers
    
    /// See `Message.body`
    public var body: Content
    
    /// See `Extendable.extend`
    public var extend: Extend
    
    /// The MediaType of this content
    public var encoder: ContentEncoder
    
    public init<C: Container>(request: Request, for container: C) throws {
        self.method = request.method
        self.uri = request.uri
        self.version = request.version
        self.headers = request.headers
        self.extend = request.extend
        
        guard
            let mediaTypeString = request.headers[.contentType],
            let mediaType = MediaType(string: mediaTypeString)
            else {
                throw HTTP.Error.contentRequired(Content.self)
        }
        
        self.encoder = try container.make(ContentEncoder.self, for: C.self)
        
        let decoder = try container.make(ContentDecoder.self, for: C.self)
        self.body = try decoder.decode(Content.self, from: request.body)
    }
    
    public func makeRequest() throws -> Request {
        let body = try encoder.encode(self.body)
        
        return Request(
            method: self.method,
            uri: self.uri,
            version: self.version,
            headers: self.headers,
            body: body
        )
    }
}
