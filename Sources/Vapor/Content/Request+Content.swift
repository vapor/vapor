extension Request {
    /// Query data from the URI path
    public var query: StructuredData? {
        get {
            return storage["query"] as? StructuredData
        }
        set(data) {
            storage["query"] = data
        }
    }

    /** 
        Request Content from Query, JSON, Form URL-Encoded, or Multipart.

        Access using PathIndexable and Polymorphic, e.g.
        
        `request.data["users", 0, "name"].string`
    */
    public var data: Content {
        get {
            guard let content = storage["content"] as? Content else {
                Log.warning("Request Content not parsed, make sure the middleware is installed.")
                return Request.Content(query: .null, request: self)
            }

            return content
        }
        set(data) {
            storage["content"] = data
        }
    }
}
