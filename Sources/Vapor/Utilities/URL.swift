/// Capable of converting to a `URL`.
public protocol URLRepresentable {
    /// Converts this type to a `URL`.
    func converToURL() -> URL?
}

extension String: URLRepresentable {
    /// See `URLRepresentable`.
    public func converToURL() -> URL? {
        return URL(string: self)
    }
}

extension URL: URLRepresentable {
    /// See `URLRepresentable`.
    public func converToURL() -> URL? {
        return self
    }
}
