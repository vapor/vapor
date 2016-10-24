import HTTP

extension Request {
    public var cookies: Cookies {
        get {
            if let cookies = storage["Cookie"] as? Cookies {
                return cookies
            } else if let string = headers["Cookie"] {
                let cookies: Cookies

                do {
                    cookies = try Cookies(string.bytes, for: .request)
                } catch {
                    print("Could not parse cookies: \(error)")
                    cookies = Cookies()
                }

                storage["Cookie"] = cookies
                return cookies
            }

            return []
        }
        set(cookie) {
            storage["Cookie"] = cookie
            
            let cookieHeader = cookie.serialize(for: .request)
            if !cookieHeader.isEmpty {
                headers["Cookie"] = cookieHeader
            } else {
                headers["Cookie"] = nil
            }
        }
    }
}
