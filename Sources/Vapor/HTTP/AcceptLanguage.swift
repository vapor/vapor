import HTTP

extension Request {
    public var lang: String {
        return headers["Accept-Language"]?.string ?? ""
    }
}
