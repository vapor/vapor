extension HTTPRequest {
    /// Sets and extracts `Cookies` from the `Request`
    public var cookies: Cookies {
        get {
            guard let cookies = self.headers[.cookie] else {
                return []
            }
            
            return Cookies(response: cookies) ?? []
        }
        set(cookies) {
            cookies.serialize(into: &self)
        }
    }
}

extension HTTPResponse {
    /// Sets and extracts `Cookies` from the `Response`
    public var cookies: Cookies {
        get {
            guard let cookies = self.headers[.cookie] else {
                return []
            }
            
            return Cookies(response: cookies) ?? []
        }
        set(cookies) {
            cookies.serialize(into: &self)
        }
    }
}
