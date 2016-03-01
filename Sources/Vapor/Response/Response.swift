import Foundation

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
        super.init(status: .MovedPermanently, data: [], contentType: .None)
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
    public typealias Writer = Socket throws -> Void
    public let writer: Writer

    public init(writer: Writer) {
        self.writer = writer
        super.init(status: .OK, data: [], contentType: .None)
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
    
    /**
     Http status representing the response
     */
    public enum Status {
        case OK, Created, Accepted
        case MovedPermanently
        case BadRequest, Unauthorized, Forbidden, NotFound
        case Error
        case Unknown
        case Custom(Int)
        
        public var code: Int {
            switch self {
            case .OK: return 200
            case .Created: return 201
            case .Accepted: return 202
                
            case .MovedPermanently: return 301
                
            case .BadRequest: return 400
            case .Unauthorized: return 401
            case .Forbidden: return 403
            case .NotFound: return 404
                
            case .Error: return 500
                
            case .Unknown: return 0
            case .Custom(let code):
                return code
            }
        }

        public var reasonPhrase: String {
            switch self {
            case .OK: return "OK"
            case .Created: return "Created"
            case .Accepted: return "Accepted"
                
            case .MovedPermanently: return "Moved Permanently"
                
            case .BadRequest: return "Bad Request"
            case .Unauthorized: return "Unauthorized"
            case .Forbidden: return "Forbidden"
            case .NotFound: return "Not Found"
                
            case .Error: return "Internal Server Error"
                
            case .Unknown: return "Unknown"
            case .Custom(let code): return "Custom \(code)"
            }
        }
    }
    
    // MARK: Member Variables

    public let status: Status
    public let data: [UInt8]
    public let contentType: ContentType
    public var headers: [String : String] = [:]
    
    public var cookies: [String : String] = [:] {
        didSet {
            if cookies.isEmpty {
                headers["Set-Cookie"] = nil
            } else {
                headers["Set-Cookie"] = cookies
                    .map { key, val in return "\(key)=\(val)" }
                    .joinWithSeparator(";")
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
    public init<T: SequenceType where T.Generator.Element == UInt8>(status: Status, data: T, contentType: ContentType) {
        self.status = status
        self.data = [UInt8](data)
        self.contentType = contentType
        switch contentType {
        case .Json:
            self.headers = ["Content-Type" : "application/json"]
        case .Html:
            self.headers = ["Content-Type" : "text/html"]
        case let .Other(description):
            self.headers = ["Content-Type" : description]
        default:
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
    public enum SerializationError: ErrorType {
        case InvalidObject
    }
    
    /**
     Convenience Initializer Error
     
     Will return 500
     
     - parameter error: a description of the server error
     */
    public convenience init(error: String) {
        let text = "{\n\t\"error\": true,\n\t\"message\":\"\(error)\"\n}"
        self.init(status: .Error, data: text.utf8, contentType: .Json)
    }
    
    /**
     Convenience Initializer - Html
     
     - parameter status: http status of response
     - parameter html: the html string to be rendered as a response
     */
    public convenience init(status: Status, html: String) {
        let serialised = "<html><meta charset=\"UTF-8\"><body>\(html)</body></html>"
        self.init(status: status, data: serialised.utf8, contentType: .Html)
    }
    
    /**
     Convenience Initializer - Text
     
     - parameter status: http status
     - parameter text: basic text response
     */
    public convenience init(status: Status, text: String) {
        self.init(status: status, data: text.utf8, contentType: .Text)
    }
    
    /**
     Convenience Initializer
     
     - parameter status: the http status
     - parameter json: any value that will be attempted to be serialized as json.  Use 'Json' for more complex objects
     
     - throws: SerializationErro
     */
    public convenience init(status: Status, json: Json) throws {
        let data = try json.serialize()
        self.init(status: status, data: data, contentType: .Json)
    }
}

extension Response: Equatable {}

public func ==(left: Response, right: Response) -> Bool {
    return left.status.code == right.status.code
}



