
/*
/**
    Responses that redirect to a supplied URL.
 */
public class Redirect: Response {

    ///The URL string for redirect
    var redirectLocation: String {
        didSet {
            headers["Location"] = redirectLocation
        }
    }

    /**
        Creates a `Response` object that redirects
        to a given URL string.

        - parameter: redirectLocation: The URL string for redirect
        
        - returns: Response
     */
    public init(to redirectLocation: String) {
        self.redirectLocation = redirectLocation
        super.init(status: .movedPermanently, data: [], contentType: .None)
        headers["Location"] = redirectLocation
    }
}

/**
    Allows for asynchronous responses. Passes
    the server Socket to the Response for writing.
    The response calls `release()` on the Socket
    when it is complete.

    Inspired by elliottminns
*/
public class AsyncResponse: Response {
    public typealias Writer = SocketIO throws -> Void
    public let writer: Writer

    public init(writer: Writer) {
        self.writer = writer
        super.init(status: .ok, data: [], contentType: .None)
    }
}

/**
    Responses are objects responsible for returning
    data to the HTTP request such as the body, status 
    code and headers.
 */
public class Response {
    
    // MARK: Types
    
    /**
        The content type of the response

        - Text: text content type
        - Html: html content type
        - Json: json content type
        - None: no content type
        - Other: non-explicit content type
    */
    public enum ContentType {
        case Text, Html, Json, None, Other(String)
    }

    
    // MARK: Member Variables

    public var status: S4.Status
    public var data: C7.Data
    public var contentType: ContentType
    public var headers: [String : String] = [:]
    
    public var cookies: [String : String] = [:] {
        didSet {
            if cookies.isEmpty {
                headers["Set-Cookie"] = nil
            } else {
                let mapped = cookies.map { key, val in
                    return "\(key)=\(val)"
                }
                
                let cookiesString = mapped.joined(separator: ";")
                headers["Set-Cookie"] = cookiesString
                
            }
        }
    }
    
*/

extension Response {
    /**
        Convenience Initializer Error

        Will return 500

        - parameter error: a description of the server error
     */
    public init(error: String) {
        self.init(status: .internalServerError, headers: [:], body: error.data)
    }

    /**
        Convenience Initializer - Html

        - parameter status: http status of response
        - parameter html: the html string to be rendered as a response
     */
    public init(status: Status, html body: String) {
        let html = "<html><meta charset=\"UTF-8\"><body>\(body)</body></html>"
        let headers: Headers = [
            "Content-Type": "text/html"
        ]
        self.init(status: status, headers: headers, body: html.data)
    }

    /**
        Convenience Initializer - Data

        - parameter status: http status
        - parameter data: response bytes
     */
    public init(status: Status, data: Data) {
        self.init(status: status, headers: [:], body: data)
    }

    /**
        Convenience Initializer - Text

        - parameter status: http status
        - parameter text: basic text response
     */
    public init(status: Status, text: String) {
        let headers: Headers = [
            "Content-Type": "text/plain"
        ]
        self.init(status: status, headers: headers, body: text.data)
    }

    /**
        Convenience Initializer

        - parameter status: the http status
        - parameter json: any value that will be attempted to be serialized as json.  Use 'Json' for more complex objects
     */
    public init(status: Status, json: Json) {
        let headers: Headers = [
            "Content-Type": "application/json"
        ]
        self.init(status: status, headers: headers, body: json.data)
    }

    /**
        Creates an empty response with the
        supplied status code.
    */
    public init(status: Status) {
        self.init(status: status, text: "")
    }

    public init(async: Void -> Void) {
        self.init(status: .ok)
    }

    public init(redirect location: String) {
        let headers: Headers = [
            "Location": Headers.Values(location)
        ]
        self.init(status: .movedPermanently, headers: headers, body: [])
    }

    public var cookies: [String: String] {
        get {
            return [:] //FIXME
        }
        set {
            //FIXME
        }
    }
}
