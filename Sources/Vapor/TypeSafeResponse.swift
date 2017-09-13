import Core
import Service
import HTTP

public final class TypeSafeResponse<Content: Codable> : ResponseRepresentable {
    public var status: Status
    
    public var version: Version
    
    public var headers: Headers
    
    public var body: Content
    
    public var extend: Extend
    
    let container: Container
    let containerType: Container.Type
    
    public init<C: Container>(response: Response, for container: C) throws {
        self.status = response.status
        self.version = response.version
        self.headers = response.headers
        self.extend = response.extend
        
        let decoder = try container.make(ContentDecoder.self, for: C.self)
        self.body = try decoder.decode(Content.self, from: response.body)
        self.container = container
        self.containerType = C.self
    }
    
    public func makeResponse(for request: Request) throws -> Response {
        guard
            let mediaTypeString = request.headers[.contentType],
            let mediaType = MediaType(string: mediaTypeString)
            else {
                throw HTTP.Error.contentRequired(Content.self)
        }
        
        let encoder = try container.unsafeMake(ContentEncoder.self, for: containerType) as! ContentEncoder
        let body = try encoder.encode(self.body)
        
        return Response(
            version: version,
            status: status,
            headers: headers,
            body: body)
    }
}
