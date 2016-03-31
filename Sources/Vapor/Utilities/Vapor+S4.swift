import S4
import C7

extension Vapor.Response {
    public var s4Response: S4.Response {
        var s4Headers: S4.Headers = [:]
        headers.forEach { (key, value) in
            s4Headers[CaseInsensitiveString(key)] = [value]
        }
        
        return S4.Response(status: status, headers: s4Headers, body: Data(data))
    }
}

extension Vapor.Request {
    public var s4Request: S4.Request {
        
        let s4Version = S4.Version(major: 1, minor: 1)
        
        var s4Headers = S4.Headers([:])
        headers.forEach { (key, value) in
            s4Headers[CaseInsensitiveString(key.string)] = HeaderValues(value)
        }
        
        return S4.Request(method: method, uri: uri, version: s4Version, headers: s4Headers, body: Body.buffer(body))
    }
}