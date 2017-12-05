extension Cookies {
    /// Seriaizes the `Cookies` for a `Request`
    public func serialize(into request: inout HTTPRequest) {
        guard !cookies.isEmpty else {
            request.headers[.cookie] = nil
            return
        }
        
        let cookie = map { cookie in
            return "\(cookie.name)=\(cookie.value)"
        }.joined(separator: "; ")
        
        request.headers[.cookie] = cookie
    }
    
    /// Seriaizes the `Cookies` for a `Response`
    public func serialize(into request: inout HTTPResponse)  {
        guard !cookies.isEmpty else {
            request.headers[.cookie] = nil
            return
        }
        
        let cookie = map { cookie in
            return cookie.serialized()
        }.joined(separator: "\r\nSet-Cookie: ")
        
        request.headers[.cookie] = cookie
    }
}

extension Cookie {
    /// Seriaizes an individual `Cookie`
    public func serialized() -> String {
        var serialized = "\(name)=\(value.value)"
        
        if let expires = value.expires {
            serialized += "; Expires=\(expires.rfc1123)"
        }
        
        if let maxAge = value.maxAge {
            serialized += "; Max-Age=\(maxAge)"
        }
        
        if let domain = value.domain {
            serialized += "; Domain=\(domain)"
        }
        
        if let path = value.path {
            serialized += "; Path=\(path)"
        }
        
        if value.secure {
            serialized += "; Secure"
        }
        
        if value.httpOnly {
            serialized += "; HttpOnly"
        }
        
        if let sameSite = value.sameSite {
            serialized += "; SameSite"
            switch sameSite {
            case .lax:
                serialized += "=Lax"
            case .strict:
                serialized += "=Strict"
            }
        }
        
        return serialized
    }
}
