import Foundation

/**
    Requests contains data sent from a client to the
    web server such as method, parameters, and data.
*/
public class Request {
    
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
    
    public typealias Handler = ((request: Request) throws -> ResponseConvertible)

    ///HTTP Method used for request.
    public let method: Method
    
    ///Query data from the path, or POST data from the body (depends on `Method`).
    public let data: Data
    
    ///Browser stored data sent with every server request
    public let cookies: [String: String]
    
    ///Path requested from server, not including hostname.
    public let path: String
    
    ///Information or metadata about the `Request`.
    public let headers: [String: String]
    
    ///Content of the `Request`.
    public let body: [UInt8]
    
    ///Address from which the `Request` originated.
    public let address: String?
    
    ///URL parameters (ex: `:id`).
    public var parameters: [String: String] = [:]
    
    ///Server stored information related from session cookie.
    public var session: Session = Session()
    
    ///Requested hostname
    public let hostname: String
    
    ///Whether the connection should be kept open for multiple Requests
    var supportsKeepAlive: Bool {
        if let value = self.headers["connection"] {
            return "keep-alive" == value.trim()
        }
        return false
    }

    init(method: Method, path: String, address: String?, headers: [String: String], body: [UInt8]) {
        self.method = method
        self.path = path.split(separator: "?")[0]
        self.address = address
        self.headers = headers
        self.body = body
        self.cookies = Request.parseCookies(headers["cookie"])
        self.hostname = headers["host"] ?? "*"
        
        let query = Request.parseQueryData(path)
        self.data = Data(query: query, bytes: body)
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
                let key = cookieArray[0].split(" ").joinWithSeparator("")
                cookies[key] = cookieArray[1]
            }
        }
        
        return cookies
    }
    
    /**
        Query data is information appended to the URL path
        as `key=value` pairs separated by `&` after
        an initial `?`
     
        - returns: String dictionary of parsed Query data
    */
    static func parseQueryData(string: String) -> [String: String] {
        
        var urlParts = string.split("?")
        if urlParts.count >= 2 {
            return self.parseData(urlParts[1])
        }
        
        return [:]
    }
    
    /**
        Parses `key=value` pair data separated by `&`.
     
        - returns: String dictionary of parsed data
    */
    static func parseData(string: String) -> [String: String] {
        var data: [String: String] = [:]
        
        for pair in string.split("&") {
            let tokens = pair.split(1, separator: "=")
            
            if let name = tokens.first, value = tokens.last {
                data[name.removePercentEncoding()] = value.removePercentEncoding()
            }
        }
        
        return data
    }

}
