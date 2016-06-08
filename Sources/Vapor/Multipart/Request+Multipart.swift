extension Request {
	/** 
		Multipart encoded request data sent using
		the `multipart/form-data...` header.

		Used by web browsers to send files.
	*/
    public var multipart: [String: Multipart]? {
        get {
            return storage["multipart"] as? [String: Multipart]
        }
        set(data) {
            storage["multipart"] = data
        }
    }
}
