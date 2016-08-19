import HTTP

extension Request {
    public var cookies: Cookies {
        get {
            if let cookies = storage["Cookie"] as? Cookies {
                return cookies
            } else if let cookies = headers["Cookie"] {
                do {
                    let cookie = try Cookies(cookies.bytes)
                    storage["Cookie"] = cookie
                    return cookie
                } catch {
                    print("Could not parse cookies: \(error)")
                    return []
                }
            } else {
                return []
            }
        }
        set(cookie) {
            storage["Cookie"] = cookie
            headers["Cookie"] = cookie.serialize(for: .request)
        }
    }
}
