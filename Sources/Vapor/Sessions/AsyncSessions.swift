/// Sessions are a method for associating data with a client accessing your app.
///
/// Each session has a unique identifier that is used to look it up with each request
/// to your app. This is usually done via HTTP cookies.
///
/// See ``Request.asyncSession`` and ``SessionsMiddleware`` for more information.
/// This is the version of ``Session`` for use with `async`/`await`
public final actor AsyncSession {
    /// This session's unique identifier. Usually a cookie value.
    public var id: SessionID?

    /// This session's data.
    public var data: SessionData

    /// `true` if this session is still valid.
    var isValid: Bool

    /// Create a new `Session`.
    ///
    /// Normally you will use `Request.session()` to do this.
    public init(id: SessionID? = nil, data: SessionData = .init()) {
        self.id = id
        self.data = data
        self.isValid = true
    }

    /// Invalidates the current session, removing persisted data from the session driver
    /// and invalidating the cookie.
    public func destroy() {
        self.isValid = false
    }
    
    public func set(_ key: String, to value: String?) {
        self.data[key] = value
    }
}
