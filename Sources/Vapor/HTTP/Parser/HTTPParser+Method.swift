private let GET = "GET".bytes
private let POST = "POST".bytes
private let PUT = "PUT".bytes
private let PATCH = "PATCH".bytes
private let DELETE = "DELETE".bytes
private let OPTIONS = "OPTIONS".bytes
private let HEAD = "HEAD".bytes
private let CONNECT = "CONNECT".bytes
private let TRACE = "TRACE".bytes

extension HTTP.Method {
    init(uppercased method: Bytes) {
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
