/**
    Requests contains data sent from a client to the
    web server such as method, parameters, and data.
*/
public class Request {
    public struct Header {
        public struct Key: StringLiteralConvertible, Hashable, Equatable, CustomStringConvertible {
            var string: String

            public init(_ string: String) {
                self.string = string
            }

            public init(unicodeScalarLiteral value: String) {
                string = "\(value)"
            }

            public init(extendedGraphemeClusterLiteral value: String) {
                string = value
            }

            public init(stringLiteral value: StringLiteralType) {
                string = value
            }

            public var description: String {
                return string
            }

            public var hashValue: Int {
                return string.lowercased().hashValue
            }
        }
    }

    ///Available HTTP Methods
    public enum Method: String {
        case Get = "GET"
        case Post = "POST"
        case Put = "PUT"
        case Patch = "PATCH"
        case Delete = "DELETE"
        case Options = "OPTIONS"
        case Unknown = "x"
    }

    public typealias Handler = ((request: Request) throws -> Response)

    ///HTTP Method used for request.
    public let method: Method

    ///Query data from the path, or POST data from the body (depends on `Method`).
    public let data: Data

    ///Browser stored data sent with every server request
    public let cookies: [String: String]

    ///Path requested from server, not including hostname.
    public let path: String

    ///Information or metadata about the `Request`.
    public let headers: [Header.Key: String]

    ///Content of the `Request`.
    public let body: [UInt8]

    ///Address from which the `Request` originated.
    public let address: String?

    ///URL parameters (ex: `:id`).
    public var parameters: [String: String] = [:]

    ///Server stored information related from session cookie.
    public var session: Session?

    ///Requested hostname
    public let hostname: String

    ///Whether the connection should be kept open for multiple Requests
    var supportsKeepAlive: Bool {
        if let value = self.headers["connection"] {
            return "keep-alive" == value.trim()
        }
        return false
    }

    public init(method: Method, path: String, address: String?, headers headersArray: [(String, String)], body: [UInt8]) {
        self.method = method
        self.path = path.split("?").first ?? ""
        self.address = address

        var headersBuffer: [Header.Key: String] = [:]
        for (key, value) in headersArray {
            headersBuffer[Request.Header.Key(key)] = value
        }
        headers = headersBuffer

        self.body = body
        self.cookies = Request.parseCookies(headers["Cookie"])
        self.hostname = headers["Host"] ?? "*"

        let query = path.queryData()
        self.data = Data(query: query, bytes: body)

        Log.verbose("Received \(method) request for \(path)")
    }

    /**
        Quickly create a Request with an empty body.
    */
    public convenience init(method: Method, path: String) {
        self.init(method: method, path: path, address: nil, headers: [], body: [])
    }

    /**
        Cookies are sent to the server as `key=value` pairs
        separated by semicolons.

        - returns: String dictionary of parsed cookies.
    */
    class func parseCookies(string: String?) -> [String: String] {
        var cookies: [String: String] = [:]

        guard let string = string else {
            return cookies
        }

        let cookieTokens = string.split(";")
        for cookie in cookieTokens {
            let cookieArray = cookie.split("=")

            if cookieArray.count == 2 {
                let split = cookieArray[0].split(" ")
                let key = split.joined(separator: "")
                cookies[key] = cookieArray[1]
            }
        }

        return cookies
    }

}
public func ==(lhs: Request.Header.Key, rhs: Request.Header.Key) -> Bool {
    return lhs.string == rhs.string
}

extension String {

    /**
        Query data is information appended to the URL path
        as `key=value` pairs separated by `&` after
        an initial `?`

        - returns: String dictionary of parsed Query data
     */
    internal func queryData() -> [String: String] {
        // First `?` indicates query, subsequent `?` should be included as part of the arguments
        return split("?", maxSplits: 1)
            .dropFirst()
            .reduce("", combine: +)
            .keyValuePairs()
    }

    /**
        Parses `key=value` pair data separated by `&`.

        - returns: String dictionary of parsed data
     */
    internal func keyValuePairs() -> [String: String] {
        var data: [String: String] = [:]

        for pair in self.split("&") {
            let tokens = pair.split("=", maxSplits: 1)

            if
                let name = tokens.first,
                let value = tokens.last,
                let parsedName = try? String(percentEncoded: name) {
                data[parsedName] = try? String(percentEncoded: value)
            }
        }

        return data
    }

}
