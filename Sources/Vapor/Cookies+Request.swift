extension Request {
    public var cookies: Cookies? {
        get {
            guard let cookies = self.headers[.cookie] else {
                return []
            }
            
            return Cookies(request: cookies)
        }
        set(cookies) {
            if let cookies = cookies {
                cookies.serialize(into: self)
            } else {
                self.headers[.cookie] = nil
            }
        }
    }
}

extension Response {
    public var cookies: Cookies? {
        get {
            guard let cookies = self.headers[.cookie] else {
                return []
            }
            
            return Cookies(response: cookies)
        }
        set(cookies) {
            if let cookies = cookies {
                cookies.serialize(into: self)
            } else {
                self.headers[.cookie] = nil
            }
        }
    }
}
