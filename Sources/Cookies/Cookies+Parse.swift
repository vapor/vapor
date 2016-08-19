import Core

extension Cookies {
    /**
        Parse Cookies from bytes in the
        formated specifiec by RFC 6265
     
             cookie=42; cookie-2=1337;
    */
    public init<B: Sequence where B.Iterator.Element == Byte>(_ bytes: B) throws {
        var cookies: Cookies = []

        // cookies are sent separated by semicolons
        let tokens = bytes.split(separator: .semicolon)

        for token in tokens {
            let cookie = try Cookie(token)
            cookies.insert(cookie)
        }
        
        self = cookies
    }
}
