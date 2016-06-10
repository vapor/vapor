extension Response {
    /**
        Response JSON. This data will be serialized
        by the JSONMiddleware into the Response body.
    */
    public var json: JSON? {
        get {
            return storage["json"] as? JSON
        }
        set(data) {
            storage["json"] = data
        }
    }

    /**
        Convenience Initializer

        - parameter status: the http status
        - parameter json: any value that will be attempted to be serialized as json.  Use 'Json' for more complex objects
     */
    public init(status: Status, json: JSON) {
        let headers: Headers = [
            "Content-Type": "application/json"
        ]
        self.init(status: status, headers: headers, data: json.data)
    }
}
