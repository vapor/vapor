import Foundation

extension Cookies {
    public init?(request string: String) {
        var cookies: Cookies = []
        
        // cookies are sent separated by semicolons
        let tokens = string.components(separatedBy: ";")
        
        for token in tokens {
            // If a single deserialization fails, the cookies are malformed
            guard let cookie = Cookie(from: token) else {
                return nil
            }
            
            cookies.append(cookie)
        }
        
        self = cookies
    }
    
    public init?(response string: String) {
        var cookies: Cookies = []
        
        // cookies are sent separated by semicolons
        let tokens = string.components(separatedBy: "\r\nSet-Cookie:")
        
        for token in tokens {
            // If a single deserialization fails, the cookies are malformed
            guard let cookie = Cookie(from: token) else {
                return nil
            }
            
            cookies.append(cookie)
        }
        
        self = cookies
    }
}

extension Cookie {
    public init?(from string: String) {
        var name: String?
        var valueString: String?
        var expires: Date?
        var maxAge: Int?
        var domain: String?
        var path: String?
        var secure = false
        var httpOnly = false
        var sameSite: Value.SameSite?
        
        // cookies are sent separated by semicolons
        let tokens = string.split(separator: ";")
        
        for token in tokens {
            let cookieTokens = token.split(separator: "=", maxSplits: 1)
            
            // cookies could be sent with space after
            // the semicolon so we should trim
            let key = cookieTokens[0].trimmingCharacters(in: [" "])
            
            let val: String
            if cookieTokens.count == 2 {
                val = String(cookieTokens[1])
            } else {
                val = ""
            }
            
            switch key.lowercased() {
            case "domain":
                domain = val
            case "path":
                path = val
            case "expires":
                expires = Date(rfc1123: val)
            case "httponly":
                httpOnly = true
            case "secure":
                secure = true
            case "max-age":
                maxAge = Int(val) ?? 0
            case "samesite":
                if val.lowercased() == "lax" {
                    sameSite = .lax
                } else {
                    sameSite = .strict
                }
            default:
                name = key
                valueString = val
            }
        }
        
        guard let cookieName = name, let value = valueString else {
            return nil
        }
        
        let cookieValue = Value(
            value: value,
            expires: expires,
            maxAge: maxAge,
            domain: domain,
            path: path,
            secure: secure,
            httpOnly: httpOnly,
            sameSite: sameSite
        )
        
        self.init(named: cookieName, value: cookieValue)
    }
}
