import Foundation

public protocol ResponseWriter {
    func write(data: [UInt8])
}

/**
    Responses that redirect to a supplied URL.
 */
public class Redirect: Response {

    ///The URL string for redirect
    var redirectLocation: String

    /**
        Redirect headers return normal `Response` headers
        while adding `Location`.

        - returns Dictionary of headers
     */
    override func headers() -> [String: String] {
        var headers = super.headers()
        headers["Location"] = self.redirectLocation
        return headers
    }

    /**
        Creates a `Response` object that redirects
        to a given URL string.

        - parameter redirectLocation: The URL string for redirect
        
        - returns Response
     */
    public init(to redirectLocation: String) {
        self.redirectLocation = redirectLocation
        super.init(status: .MovedPermanently, data: [], contentType: .None)
    }
}

/**
    Allows for asynchronous responses. Passes
    the server Socket to the Response for writing.
    The response calls `release()` on the Socket
    when it is complete.

    Inspired by elliottminns
*/
class AsyncResponse: Response {
    typealias Writer = Socket throws -> Void
    var writer: Writer

    init(writer: Writer) {
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

    public enum SerializationError: ErrorType {
        case InvalidObject
        case NotSupported
    }

    typealias WriteClosure = (ResponseWriter) throws -> Void

    let status: Status
    let data: [UInt8]
    let contentType: ContentType
    public var cookies: [String: String] = [:]

    enum ContentType {
        case Text, Html, Json, None
    }

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
    }

    var reasonPhrase: String {
        switch self.status {
        case .OK:
            return "OK"
        case .Created: 
            return "Created"
        case .Accepted: 
            return "Accepted"

        case .MovedPermanently: 
            return "Moved Permanently"

        case .BadRequest: 
            return "Bad Request"
        case .Unauthorized: 
            return "Unauthorized"
        case .Forbidden: 
            return "Forbidden"
        case .NotFound: 
            return "Not Found"

        case .Error: 
            return "Internal Server Error"
            
        case .Unknown:
            return "Unknown"
        case .Custom:
            return "Custom"    
        }
    }

    func content() -> (length: Int, writeClosure: WriteClosure?) {
        return (self.data.count, { writer in
            writer.write(self.data) 
        })
    }

    func headers() -> [String: String] {
        var headers = ["Server" : "Vapor \(Server.VERSION)"]

        if self.cookies.count > 0 {
            var cookieString = ""
            for (key, value) in self.cookies {
                if cookieString != "" {
                    cookieString += ";"
                }

                cookieString += "\(key)=\(value)"
            }
            headers["Set-Cookie"] = cookieString
        }

        switch self.contentType {
        case .Json: 
            headers["Content-Type"] = "application/json"
        case .Html: 
            headers["Content-Type"] = "text/html"
        default:
            break
        }

        return headers
    }

    init(status: Status, data: [UInt8], contentType: ContentType) {
        self.status = status
        self.data = data
        self.contentType = contentType
    }

    public convenience init(error: String) {
        let text = "{\n\t\"error\": true,\n\t\"message\":\"\(error)\"\n}"
        let data = [UInt8](text.utf8)
        self.init(status: .Error, data: data, contentType: .Json)
    }

    public convenience init(status: Status, html: String) {
        let serialised = "<html><meta charset=\"UTF-8\"><body>\(html)</body></html>"
        let data = [UInt8](serialised.utf8)
        self.init(status: status, data: data, contentType: .Html)
    }

    public convenience init(status: Status, text: String) {
        let data = [UInt8](text.utf8)
        self.init(status: status, data: data, contentType: .Text)
    }

    public convenience init(status: Status, json: Any) throws {
        let data: [UInt8]

        if let jsonObject = json as? AnyObject {
            guard NSJSONSerialization.isValidJSONObject(jsonObject) else {
                throw SerializationError.InvalidObject
            }

            let json = try NSJSONSerialization.dataWithJSONObject(jsonObject, options: NSJSONWritingOptions.PrettyPrinted)
            data = Array(UnsafeBufferPointer(start: UnsafePointer<UInt8>(json.bytes), count: json.length))
        } else {
            //fall back to manual serializer
            let string = JSONSerializer.serialize(json)
            data = [UInt8](string.utf8)
        }
       

        self.init(status: status, data: data, contentType: .Json)
    }
}


func ==(left: Response, right: Response) -> Bool {
    return left.status.code == right.status.code
}

