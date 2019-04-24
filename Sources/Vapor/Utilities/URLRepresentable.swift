/// Capable of converting `self` to a `URL`, returning `nil` if the conversion fails.
public protocol URLRepresentable {
    /// Converts `Self` to a `URL`, returning `nil` if the conversion fails.
    func convertToURL() -> URL?
}

extension URL: URLRepresentable {
    /// See `URLRepresentable`.
    public func convertToURL() -> URL? {
        return self
    }
    
    /// Returns root URL for an HTTP request.
    public static var root: URL {
        return _rootURL
    }
}

extension String: URLRepresentable {
    /// See `URLRepresentable`.
    public func convertToURL() -> URL? {
        return URL(string: self)
    }
}

/// Pre-initialized default value.
private let _rootURL = URL(string: "/")!
