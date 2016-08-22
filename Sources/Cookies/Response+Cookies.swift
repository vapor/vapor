import HTTP

extension Response {
    public var cookies: Cookies {
        get {
            if let cookies = storage["Set-Cookie"] as? Cookies {
                return cookies
            } else if let cookies = headers["Set-Cookie"] {
                do {
                    let cookie = try Cookies(cookies.bytes, for: .response)
                    storage["Set-Cookie"] = cookie
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
            storage["Set-Cookie"] = cookie
            headers["Set-Cookie"] = cookie.serialize(for: .response)
        }
    }
}
