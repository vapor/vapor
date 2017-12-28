/// Something that is convertible between a Cookie and an instance.
public final class Session {
    /// The cookie value
    public var cookie: Cookie.Value?

    /// This session's data
    public var data: [String: Encodable]

    /// Create a new session.
    public init() {
        cookie = nil
        data = [:]
    }
}
