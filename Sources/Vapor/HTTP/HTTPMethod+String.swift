import NIOHTTP1

extension HTTPMethod {
    /// `String` representation of this `HTTPMethod`.
    @available(*, deprecated, message: "Use 'rawValue' instead")
    public var string: String {
        self.rawValue
    }
}
