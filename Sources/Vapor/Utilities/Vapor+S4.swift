import S4
import C7

public typealias Byte = C7.Byte
public typealias Data = C7.Data
public typealias Stream = C7.Stream
public typealias AsyncStream = C7.AsyncStream

public typealias StructuredData = C7.StructuredData

public typealias URI = S4.URI
public typealias CaseInsensitiveString = S4.CaseInsensitiveString

extension S4.Headers {
    public typealias Key = C7.CaseInsensitiveString
}

extension Request {
    public typealias Method = S4.Method
    public typealias Body = S4.Body
    public typealias Headers = S4.Headers
    public typealias Version = S4.Version
}


public typealias Response = S4.Response
extension Response {
    public typealias Status = S4.Status
    public typealias Body = S4.Body
    public typealias Headers = S4.Headers
}

//public typealias ServerDriver = S4.Server
public protocol ServerDriver {
    init(host: String, port: Int, application: Application) throws
    func start() throws
}

public typealias Responder = S4.Responder

//public typealias Middleware = S4.Middleware
public protocol Middleware {
    func handle(_ handler: Request.Handler) -> Request.Handler
}
