import S4
import C7

public typealias Byte = C7.Byte
public typealias Data = C7.Data
public typealias Stream = C7.Stream

public typealias URI = S4.URI

public typealias Headers = S4.Headers
extension Headers {
    public typealias Values = S4.HeaderValues
    public typealias Key = C7.CaseInsensitiveString
}

public typealias Request = S4.Request
extension Request {
    public typealias Method = S4.Method
    public typealias Body = S4.Body

}

public typealias Response = S4.Response
extension Response {
    public typealias Status = S4.Status
}

public typealias Server = S4.Server
public typealias Responder = S4.Responder
