/// Something that is convertible between a Cookie and an instance.
public final class Session {
    /// The cookie value
    public var cookie: Cookie.Value?

    /// This session's data
    public var data: Encodable

    /// Create a new session.
    public init() {
        cookie = nil
        data = [:]
    }
}


extension Session {
    /// Convenience [String: String] accessor.
    public subscript(_ key: String) -> String? {
        get {
            let dict: [String: String]
            if let existing = data as? [String: String] {
                dict = existing
            } else {
                dict = [:]
            }
            return dict[key]
        }
        set {
            var dict: [String: String]
            if let existing = data as? [String: String] {
                dict = existing
            } else {
                dict = [:]
            }
            dict[key] = newValue
            data = dict
        }
    }
}
