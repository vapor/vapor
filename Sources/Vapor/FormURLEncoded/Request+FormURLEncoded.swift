extension Request {
    /// JSON encoded request data
    public var formURLEncoded: StructuredData? {
        get {
            return storage["form-urlencoded"] as? StructuredData
        }
        set(data) {
            storage["form-urlencoded"] = data
        }
    }
}
