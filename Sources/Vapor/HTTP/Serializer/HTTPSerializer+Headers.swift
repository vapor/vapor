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
        case .data(let bytes) where !bytes.isEmpty:
            self["Content-Length"] = bytes.count.description
        default:
            // empty data ok, but do NOT set Content-Length to 0, it will breaks nginx
            return
        }
    }

    private mutating func setTransferEncodingChunked() {
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
