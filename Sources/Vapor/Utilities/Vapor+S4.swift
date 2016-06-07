import S4
import C7

public typealias Byte = C7.Byte
public typealias Data = C7.Data
public typealias Stream = C7.Stream
public typealias StructuredData = C7.StructuredData

public typealias URI = S4.URI
public typealias CaseInsensitiveString = S4.CaseInsensitiveString

extension Request {
    public typealias Method = S4.Method
    public typealias Body = S4.Body
    public typealias Headers = S4.Headers
    public typealias Version = S4.Version
}

extension Response {
    public typealias Status = S4.Status
    public typealias Headers = S4.Headers
    public typealias Version = S4.Version
    public typealias Cookies = S4.Cookies
    public typealias Cookie = S4.Cookie
}
