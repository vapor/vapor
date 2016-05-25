import S4
import C7

public typealias Byte = C7.Byte
public typealias Data = C7.Data
public typealias Stream = C7.Stream
public typealias AsyncStream = C7.AsyncStream

public typealias StructuredData = C7.StructuredData

public typealias URI = S4.URI

extension S4.Headers {
    public typealias Values = S4.Header
    public typealias Key = C7.CaseInsensitiveString
}

public typealias Request = S4.Request
extension Request {
    public typealias Method = S4.Method
    public typealias Body = S4.Body
    public typealias Headers = S4.Headers
    public typealias Header = S4.Header
}


public typealias Response = S4.Response
extension Response {
    public typealias Status = S4.Status
    public typealias Body = S4.Body
    public typealias Headers = S4.Headers
}

public typealias Server = S4.Server
public typealias Responder = S4.Responder

public typealias Middleware = S4.Middleware
