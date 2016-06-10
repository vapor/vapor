extension Request {
    public var cookies: [String: String] {
        get {
            guard let cookies = storage["cookies"] as? [String: String] else {
                return [:]
            }

            return cookies
        }
        set(data) {
            storage["cookies"] = cookies
        }
    }
}
