import HTTP

extension Response {
    public var cookies: Cookies {
        get {
            if let cookies = storage["Set-Cookie"] as? Cookies {
                return cookies
            } else if let string = headers["Set-Cookie"] {
                let cookies: Cookies

                do {
                    cookies = try Cookies(string.bytes, for: .response)
                } catch {
                    print("Could not parse cookies: \(error)")
                    cookies = Cookies()
                }
                
                storage["Set-Cookie"] = cookies
                return cookies
            }

            return []
        }
        set(cookie) {
            storage["Set-Cookie"] = cookie
            
            let cookieHeader = cookie.serialize(for: .response)
            if !cookieHeader.isEmpty {
                headers["Set-Cookie"] = cookieHeader
            } else {
                headers["Set-Cookie"] = nil
            }
        }
    }
}
