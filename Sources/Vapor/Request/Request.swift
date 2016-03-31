import C7
import S4

/**
    Requests contains data sent from a client to the
    web server such as method, parameters, and data.
*/
public class Request {
    public typealias Handler = ((request: Request) throws -> Response)

    ///HTTP Method used for request.
    public let method: S4.Method
    
    ///Query data from the path, or POST data from the body (depends on `Method`).
    public let data: Request.Data
    
    ///Browser stored data sent with every server request
    public let cookies: [String: String]
    
    ///URI requested from server, not including hostname
    public let uri: S4.URI
    
    ///Information or metadata about the `Request`.
    public let headers: S4.Headers
    
    ///Content of the `Request`.
    public let body: C7.Data
    
    ///Address from which the `Request` originated.
    public let address: String?
    
    ///URL parameters (ex: `:id`).
    public var parameters: [String: String] = [:]
    
    ///Server stored information related from session cookie.
    public var session: Session?
    
    ///Whether the connection should be kept open for multiple Requests
    var supportsKeepAlive: Bool {
        if let value = headers["connection"].first {
            return "keep-alive" == value.trim()
        }
        return false
    }

    public init(method: Method, path: String, address: String?, headers: S4.Headers, body: C7.Data) {
        self.method = method
        self.address = address
        
        self.headers = headers

        
        let path = path.split("?").first ?? ""
        let host = headers["Host"].first ?? "*"
        
        
        self.body = body
        self.cookies = Request.parseCookies(headers["Cookie"].first)
        
        
        let query = path.queryData()
        self.data = Data(query: query, bytes: body.bytes)
        
        uri = S4.URI(scheme: "http", userInfo: nil, host: host, port: nil, path: path, query: [], fragment: nil)
        
        Log.verbose("Received \(method) request for \(path)")
    }
    
    /**
        Quickly create a Request with an empty body.
    */
    public convenience init(method: Method, path: String) {
        self.init(method: method, path: path, address: nil, headers: [:], body: [])
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
