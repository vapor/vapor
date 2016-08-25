import Core
import Foundation

extension Cookie {
    /**
        Errors that can happen
        when parsing a Cookie.
    */
    public enum Error: Swift.Error {
        case invalidBytes
    }

    /**
        Parse Cookie from bytes in the
        formated specifiec by RFC 6265

        cookie=42; Domain=.foo.com
    */
    public init<B: Sequence>(_ bytes: B) throws where B.Iterator.Element == Byte {
        var name: String?
        var value: String?
        var expires: Date?
        var maxAge: Int?
        var domain: String?
        var path: String?
        var secure = false
        var httpOnly = false


        // cookies are sent separated by semicolons
        let tokens = bytes .split(separator: .semicolon)
        for token in tokens {
            let cookieTokens = token.split(separator: .equals, maxSplits: 1)

            // cookies could be sent with space after
            // the semicolon so we should trim
            let key = Array(cookieTokens[0]).trimmed([.space]).string

            let val: String
            if cookieTokens.count == 2 {
                val = cookieTokens[1].string
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
            default:
                name = key
                value = val
            }
        }

        guard
            let n = name,
            let v = value
        else {
            throw Error.invalidBytes
        }

        self.init(
            name: n,
            value: v,
            expires: expires,
            maxAge: maxAge,
            domain: domain,
            path: path,
            secure: secure,
            httpOnly: httpOnly
        )
    }

    public init(_ string: String) throws {
        try self.init(string.bytes)
    }
}
