import libc

public final class Response {
    public var version: Version
    public var status: Status
    public var headers: Headers
    public var cookies: Cookies
    public var body: Body

    public init(status: Status = .ok, headers: Headers = [:], cookies: Cookies = [], data: Data = []) {
        self.version = Version(major: 1, minor: 1)
        self.status = status
        self.headers = headers
        self.cookies = cookies
        self.body = .buffer(data)
    }


    public init(status: Status = .ok, headers: Headers = [:], cookies: Cookies = [], async closure: ((Stream) throws -> Void)) {
        self.version = Version(major: 1, minor: 1)
        self.status = status
        self.headers = headers
        self.headers["Transfer-Encoding"] = "chunked"
        self.cookies = cookies
        self.body = .async(closure)
    }
}

extension Response {
    public enum Body {
        case buffer(Data)
        case async((Stream) throws -> ())
    }
}

extension Response {
    /**
        Convenience Initializer Error

        Will return 500

        - parameter error: a description of the server error
     */
    public convenience init(error: String) {
        self.init(status: .internalServerError, headers: [:], data: error.data)
    }

    /**
        Convenience Initializer - Html

        - parameter status: http status of response
        - parameter html: the html string to be rendered as a response
     */
    public convenience init(status: Status, html body: String) {
        let html = "<html><meta charset=\"UTF-8\"><body>\(body)</body></html>"
        self.init(status: status, headers: [
            "Content-Type": "text/html"
        ], data: html.data)
    }

    /**
        Convenience Initializer - Text

        - parameter status: http status
        - parameter text: basic text response
     */
    public convenience init(status: Status, text: String) {
        self.init(status: status, headers: [
            "Content-Type": "text/plain"
        ], data: text.data)
    }

    /**
        Convenience Initializer

        - parameter status: the http status
        - parameter json: any value that will be attempted to be serialized as json.  Use 'Json' for more complex objects
     */
    public convenience init(status: Status, json: JSON) {
        self.init(status: status, headers: [
            "Content-Type": "application/json"
        ], data: json.data)
    }

    /**
        Creates an empty response with the
        supplied status code.
    */
    public convenience init(status: Status) {
        self.init(status: status, text: "")
    }

    public convenience init(redirect location: String) {
        self.init(status: .movedPermanently, headers: [
            "Location": location
        ])
    }

    public static var date: String {
        let DAY_NAMES = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let MONTH_NAMES = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

        let RFC1123_TIME_LEN = 29
        var t: time_t = 0
        var tm: libc.tm = libc.tm()

        let buf = UnsafeMutablePointer<Int8>.init(allocatingCapacity: RFC1123_TIME_LEN + 1)
        defer { buf.deallocateCapacity(RFC1123_TIME_LEN + 1) }

        time(&t)
        gmtime_r(&t, &tm)

        strftime(buf, RFC1123_TIME_LEN+1, "---, %d --- %Y %H:%M:%S GMT", &tm)
        memcpy(buf, DAY_NAMES[Int(tm.tm_wday)], 3)
        memcpy(buf+8, MONTH_NAMES[Int(tm.tm_mon)], 3)


        return String(pointer: buf, length: RFC1123_TIME_LEN + 1) ?? ""
    }
}
