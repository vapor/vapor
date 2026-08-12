/// A structure representing a HTTP version.
public struct HTTPVersion: Equatable, Sendable {
    /// Create a HTTP version.
    ///
    /// - Parameter major: The major version number.
    /// - Parameter minor: The minor version number.
    @inlinable
    public init(major: Int, minor: Int) {
        self._major = UInt16(major)
        self._minor = UInt16(minor)
    }

    @usableFromInline var _minor: UInt16
    @usableFromInline var _major: UInt16

    /// The major version number.
    @inlinable
    public var major: Int {
        get {
            Int(self._major)
        }
        set {
            self._major = UInt16(newValue)
        }
    }

    /// The minor version number.
    @inlinable
    public var minor: Int {
        get {
            Int(self._minor)
        }
        set {
            self._minor = UInt16(newValue)
        }
    }

    /// HTTP/3
    @inlinable
    public static var http3: HTTPVersion {
        HTTPVersion(major: 3, minor: 0)
    }

    /// HTTP/2
    @inlinable
    public static var http2: HTTPVersion {
        HTTPVersion(major: 2, minor: 0)
    }

    /// HTTP/1.1
    @inlinable
    public static var http1_1: HTTPVersion {
        HTTPVersion(major: 1, minor: 1)
    }

    /// HTTP/1.0
    @inlinable
    public static var http1_0: HTTPVersion {
        HTTPVersion(major: 1, minor: 0)
    }

    /// HTTP/0.9 (not supported by SwiftNIO)
    @inlinable
    public static var http0_9: HTTPVersion {
        HTTPVersion(major: 0, minor: 9)
    }
}
