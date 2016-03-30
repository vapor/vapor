import S4
import C7

/**
    The beginning of S4 integration.
*/
public typealias Byte = C7.Byte
public typealias Data = C7.Data

extension Vapor.Response.Status {
    var s4Status: S4.Status {
        return S4.Status(statusCode: code, reasonPhrase: reasonPhrase)
    }
}

extension Vapor.Response {
    public var s4Response: S4.Response {
        var s4Headers: S4.Headers = [:]
        headers.forEach { (key, value) in
            s4Headers[CaseInsensitiveString(key)] = [value]
        }
        
        return S4.Response(status: status.s4Status, headers: s4Headers, body: Data(data))
    }
}

extension Vapor.Request.Method {
    public var s4Method: S4.Method {
        return .get
    }
}


extension Vapor.Request {
    public var s4Request: S4.Request {
        let s4Uri = S4.URI(scheme: "http", userInfo: nil, host: nil, port: nil, path: path, query: [], fragment: nil)
        
        let s4Version = S4.Version(major: 1, minor: 1)
        
        var s4Headers = S4.Headers([:])
        headers.forEach { (key, value) in
            s4Headers[CaseInsensitiveString(key.string)] = HeaderValues(value)
        }
        
        return S4.Request(method: method.s4Method, uri: s4Uri, version: s4Version, headers: s4Headers, body: Body.buffer(body))
    }
}