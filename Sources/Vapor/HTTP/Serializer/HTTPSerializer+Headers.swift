//extension Headers {
//    mutating func appendHost(for uri: URI) {
//        // TODO: Should this overwrite, or only if non-existant so user can customize if there's something we're not considering
//        guard self["Host"] == nil else { return }
//        self["Host"] = uri.host
//    }
//
//    mutating func appendMetadata(for body: HTTPBody) {
//        switch body {
//        case .chunked(_):
//            setTransferEncodingChunked()
//        case .data(let bytes):
//            // Can't have transfer encoding w/ data payload
//            self["Transfer-Encoding"] = nil
//            self["Content-Length"] = bytes.count.description
//        }
//    }
//
//    mutating func setTransferEncodingChunked() {
//        // Remove Content Length For Chunked Encoding
//        self["Content-Length"] = nil
//
//        if let encoding = self["Transfer-Encoding"] where !encoding.isEmpty {
//            if encoding.hasSuffix("chunked") {
//                return
//            } else {
//                self["Transfer-Encoding"] = encoding + ", chunked"
//            }
//        } else {
//            self["Transfer-Encoding"] = "chunked"
//        }
//    }
//}
