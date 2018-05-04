/// Sessions are a method for associating data with a client accessing your app.
///
/// Each session has a unique identifier that is used to look it up with each request
/// to your app. This is usually done via HTTP cookies.
///
/// See `Request.session()` and `SessionsMiddleware` for more information.
public final class Session {
    /// This session's unique identifier. Usually a cookie value.
    public var id: String?

    /// This session's data.
    public var data: SessionData

    /// Create a new `Session`.
    ///
    /// Normally you will use `Request.session()` to do this.
    public init(id: String? = nil, data: SessionData = .init()) {
        self.id = id
        self.data = data
    }

    /// Convenience `[String: String]` accessor.
    public subscript(_ key: String) -> String? {
        get { return data.storage[key] }
        set { data.storage[key] = newValue }
    }
}
