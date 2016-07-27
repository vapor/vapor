import Engine

extension HTTPRequest {
    /**
        Multipart encoded request data sent using
        the `multipart/form-data...` header.

        Used by web browsers to send files.
    */
    public var multipart: [String: Multipart]? {
        if let existing = storage["multipart"] as? [String: Multipart] {
            return existing
        } else if let type = headers["Content-Type"], type.contains("multipart/form-data") {
            guard case let .data(body) = body else { return nil }
            guard let boundary = try? Multipart.parseBoundary(contentType: type) else { return nil }
            let multipart = Multipart.parse(body, boundary: boundary)
            storage["multipart"] = multipart
            return multipart
        } else {
            return nil
        }
    }
}
