import C7
import S4

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
    
    // MARK: Initialization
    
    /**
        Designated Initializer

        - parameter status: http status of response
        - parameter data: the byte sequence that will be transmitted
        - parameter contentType: the content type that the data represents
    */
    public init(status: Status, data: Data, contentType: ContentType) {
        self.status = status
        self.data = data
        self.contentType = contentType
        switch contentType {
        case .Json:
            self.headers = ["Content-Type": "application/json"]
        case .Html:
            self.headers = ["Content-Type": "text/html"]
        case let .Other(description):
            self.headers = ["Content-Type": description]
        case .Text:
            self.headers = ["Content-Type": "text"]
        case .None:
            self.headers = [:]
        }
        
        self.headers["Server"] = "Vapor \(Application.VERSION)"
    }
}

// MARK: - Convenience Initializers
extension Response {
    /**
        When attempting to serialize an object of type 'Any' into Json,
        invalid objects will throw

        - InvalidObject: the object to serialize is not a valid Json object
    */
    public enum SerializationError: ErrorProtocol {
        case InvalidObject
    }
    
    /**
         Convenience Initializer Error
         
         Will return 500
         
         - parameter error: a description of the server error
    */
    public convenience init(error: String) {
        self.init(status: .internalServerError, data: error.data, contentType: .Json)
    }
    
    /**
         Convenience Initializer - Html
         
         - parameter status: http status of response
         - parameter html: the html string to be rendered as a response
    */
    public convenience init(status: S4.Status, html: String) {
        let serialised = "<html><meta charset=\"UTF-8\"><body>\(html)</body></html>"
        self.init(status: status, data: serialised.data, contentType: .Html)
    }
    
    /**
         Convenience Initializer - Text
         
         - parameter status: http status
         - parameter text: basic text response
    */
    public convenience init(status: S4.Status, text: String) {
        self.init(status: status, data: text.data, contentType: .Text)
    }
    
    /**
         Convenience Initializer
         
         - parameter status: the http status
         - parameter json: any value that will be attempted to be serialized as json.  Use 'Json' for more complex objects
    */
    public convenience init(status: S4.Status, json: Json) {
        self.init(status: status, data: json.data, contentType: .Json)
    }

    /**
        Creates an empty response with the
        supplied status code.
    */
    public convenience init(status: S4.Status) {
        self.init(status: status, text: "")
    }
}

extension Response: Equatable {}

public func ==(left: Response, right: Response) -> Bool {
    return left.status == right.status
}



