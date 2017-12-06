/// HTTP version.
public struct HTTPVersion: Codable {
    /// Version major, i.e. 1 in HTTP/1.0
    public var major: Int
    /// Version minor, i.e., 0 in HTTP/1.0
    public var minor: Int

    /// Create a new HTTP version.
    public init(major: Int, minor: Int) {
        self.major = major
        self.minor = minor
    }
}

