extension Request {
    /// JSON encoded request data
    public var json: JSON? {
        get {
            return storage["json"] as? JSON
        }
        set(data) {
            storage["json"] = data
        }
    }
}
