import S4
import C7

public typealias Byte = C7.Byte
public typealias Data = C7.Data
public typealias URI = C7.URI
public typealias SendingStream = C7.SendingStream
public typealias StructuredData = C7.StructuredData

extension S4.Headers {
    public typealias Key = C7.CaseInsensitiveString
}

//public typealias Body = S4.Body
public typealias Headers = S4.Headers
public typealias Version = S4.Version

//extension HTTP.Request {
//    public typealias Method = S4.Method
//}

public typealias Status = S4.Status
public typealias Method = S4.Method

//public typealias Response = S4.Response
//extension Response {
//    public typealias Status = S4.Status
//}


public typealias ServerDriver = HTTPServerProtocol
//public typealias Responder = S4.Responder

// TODO: ? Convenient to have as top level
public typealias Middleware = HTTPMiddleware
public protocol HTTPMiddleware {
    func respond(to request: HTTP.Request, chainingTo next: HTTPResponder) throws -> HTTP.Response
}
