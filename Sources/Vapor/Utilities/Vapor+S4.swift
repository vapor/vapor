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

public typealias Body = S4.Body
public typealias Headers = S4.Headers
public typealias Version = S4.Version

public typealias Request = S4.Request
extension Request {
    public typealias Method = S4.Method
}

public typealias Response = S4.Response
extension Response {
    public typealias Status = S4.Status
}


public typealias ServerDriver = S4.Server
public typealias Responder = S4.Responder

public typealias Middleware = S4.Middleware
