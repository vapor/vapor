import Synchronization

/// Sessions are a method for associating data with a client accessing your app.
///
/// Each session has a unique identifier that is used to look it up with each request
/// to your app. This is usually done via HTTP cookies.
///
/// See ``Request/session`` and ``SessionsMiddleware`` for more information.
public final class Session: Sendable {
    struct Storage: Sendable {
        var id: SessionID?
        var data: SessionData
        var isValid: Bool = true
    }

    let storage: Mutex<Storage>

    /// This session's unique identifier. Usually a cookie value.
    public var id: SessionID? {
        get {
            self.storage.withLock { $0.id }
        }
        set {
            self.storage.withLock { $0.id = newValue }
        }
    }

    /// This session's data.
    public var data: SessionData {
        get {
            self.storage.withLock { $0.data }
        }
        set {
            self.storage.withLock { $0.data = newValue }
        }
    }

    /// `true` if this session is still valid.
    var isValid: Bool {
        self.storage.withLock { $0.isValid }
    }

    /// Create a new `Session`.
    ///
    /// Normally you will use `Request.session()` to do this.
    public init(id: SessionID? = nil, data: SessionData = .init()) {
        self.storage = .init(.init(id: id, data: data))
    }

    /// Invalidates the current session, removing persisted data from the session driver
    /// and invalidating the cookie.
    public func destroy() {
        self.storage.withLock { $0.isValid = false }
    }
}

public struct SessionID: Sendable, Equatable, Hashable {
    public let string: String
    
    public init(string: String) {
        self.string = string
    }
}

extension SessionID: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        try self.init(string: container.decode(String.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.string)
    }
}
