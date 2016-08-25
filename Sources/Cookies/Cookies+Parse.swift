import Core

extension Cookies {
    public enum ParseMethod {
        case request, response
    }

    /**
        Parse Cookies from bytes in the
        formated specifiec by RFC 6265
     
             cookie=42; cookie-2=1337;
    */
    public init<B: Sequence where B.Iterator.Element == Byte>(_ bytes: B, for method: ParseMethod) throws {
        var cookies: Cookies = []

        // cookies are sent separated by semicolons
        let tokens: [String]
        switch method {
        case .request:
            tokens = bytes.string.components(separatedBy: ";")
        case .response:
            tokens = bytes.string.components(separatedBy: "\r\nSet-Cookie:")
        }

        for token in tokens {
            let cookie = try Cookie(token)
            cookies.insert(cookie)
        }
        
        self = cookies
    }
}
