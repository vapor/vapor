import NIOHTTP1

extension HTTPMethod {
    /// `String` representation of this `HTTPMethod`.
    @available(*, deprecated, renamed: "rawValue")
    public var string: String {
        self.rawValue
    }
}
