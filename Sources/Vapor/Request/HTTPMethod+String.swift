extension HTTPMethod {
    /// `String` representation of this `HTTPMethod`.
    public var string: String {
        switch self {
        case .GET: return "GET"
        default: return "\(self)"
        }
    }
}
