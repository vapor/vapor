import Core
import Service
import HTTP

/// An HTTP Request with a type-safe body
public final class TypeSafeRequest<Content: Codable> {
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
    
    public init(
        method: Method = .get,
        uri: URI = URI(),
        version: Version = Version(major: 1, minor: 1),
        headers: Headers = Headers(),
        body: Content
        ) {
        self.method = method
        self.uri = uri
        self.version = version
        self.headers = headers
        self.body = body
        self.extend = Extend()
    }
    
    public init<C: Container>(request: Request, for container: C) throws {
        self.method = request.method
        self.uri = request.uri
        self.version = request.version
        self.headers = request.headers
        self.extend = request.extend
        
        // TODO: Detect content type
        
        let decoder = try container.make(ContentDecoder.self, for: C.self)
        self.body = try decoder.decode(Content.self, from: request.body)
    }
    
    public func makeRequest(using encoder: ContentEncoder) throws -> Request {
        let body = try encoder.encodeBody(from: self.body)
        
        var headers = self.headers
        headers[.contentType] = encoder.type.description
        
        return Request(
            method: self.method,
            uri: self.uri,
            version: self.version,
            headers: self.headers,
            body: body
        )
    }
}
