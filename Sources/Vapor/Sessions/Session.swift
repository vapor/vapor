import NIOConcurrencyHelpers

/// Sessions are a method for associating data with a client accessing your app.
///
/// Each session has a unique identifier that is used to look it up with each request
/// to your app. This is usually done via HTTP cookies.
///
/// See `Request.session()` and `SessionsMiddleware` for more information.
public final class Session: @unchecked Sendable {
    /// This session's unique identifier. Usually a cookie value.
    public var id: SessionID? {
        get {
            idLock.withLock {
                return _id
            }
        }
        set {
            idLock.withLockVoid {
                _id = newValue
            }
        }
    }

    /// This session's data.
    public var data: SessionData {
        get {
            dataLock.withLock {
                return _data
            }
        }
        set {
            dataLock.withLockVoid {
                _data = newValue
            }
        }
    }

    /// `true` if this session is still valid.
    var isValid: Bool {
        get {
            isValidLock.withLock {
                return _isValid
            }
        }
        set {
            isValidLock.withLockVoid {
                _isValid = newValue
            }
        }
    }
    
    private var _id: SessionID?
    private var _data: SessionData
    private var _isValid: Bool
    private let idLock: NIOLock
    private let dataLock: NIOLock
    private let isValidLock: NIOLock

    /// Create a new `Session`.
    ///
    /// Normally you will use `Request.session()` to do this.
    public init(id: SessionID? = nil, data: SessionData = .init()) {
        self.idLock = .init()
        self.dataLock = .init()
        self.isValidLock = .init()
        self._id = id
        self._data = data
        self._isValid = true
    }

    /// Invalidates the current session, removing persisted data from the session driver
    /// and invalidating the cookie.
    public func destroy() {
        self.isValid = false
    }
}

public struct SessionID: Equatable, Hashable, Sendable {
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
