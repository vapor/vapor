import NIOHTTP1

extension HTTPMethod {
    /// `String` representation of this `HTTPMethod`.
    public var string: String {
        switch self {
        case .GET: return "GET"
        case .RAW(let value): return value
        default: return "\(self)"
        }
    }
}
