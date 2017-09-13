import Core
import Service
import HTTP

public final class TypeSafeResponse<Content: Codable> {
    public var status: Status
    
    public var version: Version
    
    public var headers: Headers
    
    public var body: Content
    
    public var extend: Extend
    
    public init(
        version: Version = Version(major: 1, minor: 1),
        status: Status = .ok,
        headers: Headers = Headers(),
        body: Content
        ) {
        self.version = version
        self.status = status
        self.headers = headers
        self.body = body
        self.extend = Extend()
    }
    
    public init<C: Container>(response: Response, for container: C) throws {
        self.status = response.status
        self.version = response.version
        self.headers = response.headers
        self.extend = response.extend
        
        let decoder = try container.make(ContentDecoder.self, for: C.self)
        self.body = try decoder.decode(Content.self, from: response.body)
    }
    
    public func makeResponse<C: Container>(for request: Request, for container: C) throws -> Response {
        // TODO: Detect request accept type(s)
        let encoder = try container.make(ContentEncoder.self, for: C.self)
        let body = try encoder.encodeBody(from: self.body)
        
        return Response(
            version: version,
            status: status,
            headers: headers,
            body: body)
    }
}
