import Engine

extension HTTPResponse {
    public var cookies: Cookies {
        get {
            if let cookies = storage["Set-Cookie"] as? Cookies {
                return cookies
            } else if let cookieString = headers["Set-Cookie"] {
                let cookie = Cookies(cookieString)
                storage["Set-Cookie"] = cookie
                return cookie
            } else {
                return []
            }
        }
        set(cookie) {
            storage["Set-Cookie"] = cookie
            headers["Set-Cookie"] = cookie.serialize()
        }
    }
}
