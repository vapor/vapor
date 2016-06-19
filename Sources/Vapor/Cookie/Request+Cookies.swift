extension HTTPRequest {
    public var cookies: Cookies? {
        get {
            if let cookies = storage["Cookie"] as? Cookies {
                return cookies
            } else if let cookieString = headers["Cookie"] {
                let cookie = Cookies(cookieString)
                storage["Cookie"] = cookie
                return cookie
            } else {
                return nil
            }
        }
        set(cookie) {
            storage["Cookie"] = cookie
            headers["Cookie"] = cookie?.serialize()
        }
    }
}
