import libc
import S4

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
    public init(status: Status, json: JSON) {
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

    public init(redirect location: String) {
        let headers: Headers = [
            "Location": location
        ]
        self.init(status: .movedPermanently, headers: headers, body: [])
    }

    public init(async closure: ((SendingStream) throws -> Void)) {
        self.init(body: closure)
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

extension Response {
    public typealias AfterResponseSerialization = ((Stream) throws -> Void)

    public var afterResponseSerialization: AfterResponseSerialization? {
        get {
            return storage["vapor:afterResponseSerialization"] as? AfterResponseSerialization
        }
        set {
            storage["vapor:afterResponseSerialization"] = newValue
        }
    }
}
