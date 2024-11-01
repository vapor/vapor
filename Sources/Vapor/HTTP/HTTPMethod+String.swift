import NIOHTTP1

extension HTTPMethod {
    /// `String` representation of this `HTTPMethod`.
    public var string: String {
        self.rawValue
    }
}
