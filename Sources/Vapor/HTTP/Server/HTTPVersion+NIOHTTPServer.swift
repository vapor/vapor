import NIOHTTPServer

extension HTTPVersion {
    /// Converts the HTTP version reported by the underlying HTTP server for the connection carrying a request.
    init(_ version: NIOHTTPServer.HTTPVersion) {
        switch version {
        case .plaintextHTTP1_1, .http1_1:
            self = .http1_1
        case .http2:
            self = .http2
        #if UnstableHTTP3
        case .http3:
            self = .http3
        #endif
        @unknown default:
            self = .http1_1
        }
    }
}
