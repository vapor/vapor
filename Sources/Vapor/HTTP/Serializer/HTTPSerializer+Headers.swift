extension Headers {
    mutating func ensureConnection() {
        if self["Connection"].isNilOrEmpty {
            self["Connection"] = "close"
        }
    }

    mutating func appendHost(for uri: URI) {
        // TODO: Should this overwrite, or only if non-existant so user can customize if there's something we're not considering
        guard self["Host"] == nil else { return }
        self["Host"] = uri.host
    }

    mutating func appendMetadata(for body: HTTP.Body) {
        switch body {
        case .chunked(_):
            setTransferEncodingChunked()
        case .data(let bytes):
            // Can't have transfer encoding w/ data payload
            self["Transfer-Encoding"] = nil
            if bytes.isEmpty {
                // Empty payload MUST NOT have length of `0`, content length should be empty
                self["Content-Length"] = nil
            } else {
                self["Content-Length"] = bytes.count.description
            }
        }
    }

    private mutating func setTransferEncodingChunked() {
        // Remove Content Length For Chunked Encoding
        self["Content-Length"] = nil

        if let encoding = self["Transfer-Encoding"] where !encoding.isEmpty {
            if encoding.hasSuffix("chunked") {
                return
            } else {
                self["Transfer-Encoding"] = encoding + ", chunked"
            }
        } else {
            self["Transfer-Encoding"] = "chunked"
        }
    }
}
