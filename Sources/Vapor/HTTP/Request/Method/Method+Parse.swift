import S4

private let GET = "GET".bytesSlice
private let POST = "POST".bytesSlice
private let PUT = "PUT".bytesSlice
private let PATCH = "PATCH".bytesSlice
private let DELETE = "DELETE".bytesSlice
private let OPTIONS = "OPTIONS".bytesSlice
private let HEAD = "HEAD".bytesSlice
private let CONNECT = "CONNECT".bytesSlice
private let TRACE = "TRACE".bytesSlice

extension Method {
    init(uppercase method: BytesSlice) {
        switch method {
        case GET:
            self = .get
        case POST:
            self = .post
        case PUT:
            self = .put
        case PATCH:
            self = .patch
        case DELETE:
            self = .delete
        case OPTIONS:
            self = .options
        case HEAD:
            self = .head
        case CONNECT:
            self = .connect
        case TRACE:
            self = .trace
        default:
            self = .other(method: method.string)
        }
    }
}
