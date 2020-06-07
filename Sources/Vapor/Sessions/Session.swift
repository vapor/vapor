/// Sessions are a method for associating data with a client accessing your app.
///
/// Each session has a unique identifier that is used to look it up with each request
/// to your app. This is usually done via HTTP cookies.
///
/// See `Request.session()` and `SessionsMiddleware` for more information.
public final class Session {
    /// This session's unique identifier. Usually a cookie value.
    public var id: SessionID?

    /// This session's data.
    public var data: SessionData

    /// `true` if this session is still valid.
    var isValid: Bool

    /// Create a new `Session`.
    ///
    /// Normally you will use `Request.session()` to do this.
    public init(
        id: SessionID? = nil,
        data: SessionData = .init()) {
        self.id = id
        self.data = data
        self.isValid = true
    }

    /// Flag the current session as invalid. Persisted data will be removed from the session
    /// driver when `SessionsMiddleware` checks this flag at response time.
    public func destroy() {
        self.isValid = false
    }
}

public struct SessionID: Equatable, Hashable {
    public let string: String
    public init(string: String) {
        self.string = string
    }
}

extension SessionID: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        try self.init(string: container.decode(String.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.string)
    }
}
