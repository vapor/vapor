#if UnstableWebTransport

import HTTPTypes
public import RoutingKit

extension RoutesBuilder {
    /// Adds a route for handling WebTransport over HTTP/3 sessions.
    ///
    /// - Parameters:
    ///   - path: The path components of the WebTransport route.
    ///   - closure: The closure where WebTransport operations using the session are performed.
    ///
    /// - Returns: ``Route`` instance for the newly created WebTransport over HTTP/3 endpoint.
    @discardableResult
    public func webTransport(
        _ path: PathComponent...,
        session closure: @Sendable @escaping (consuming WebTransportSession) async throws -> Void
    ) -> Route {
        self.webTransport(path, session: closure)
    }

    /// Adds a route for handling WebTransport over HTTP/3 sessions.
    ///
    /// - Parameters:
    ///   - path: The path components of the WebTransport route.
    ///   - closure: The closure where WebTransport operations using the session are performed.
    ///
    /// - Returns: ``Route`` instance for the newly created WebTransport over HTTP/3 endpoint.
    @discardableResult
    public func webTransport(
        _ path: [PathComponent],
        session closure: @Sendable @escaping (consuming WebTransportSession) async throws -> Void
    ) -> Route {
        self.on(.connect, path) { request -> Response in
            guard request.extendedConnectProtocol == "webtransport-h3" || request.extendedConnectProtocol == "webtransport" else {
                throw Abort(.forbidden)
            }
            let responseHeaders: HTTPFields =
                if let wtProtocol = request.headers[values: .webTransportAvailableProtocols].first {
                    [.webTransportProtocol: wtProtocol]
                } else {
                    [:]
                }
            return Response(status: .ok, headers: responseHeaders, webTransportSession: closure)
        }
    }
}

extension HTTPField.Name {
    /// WT-Protocol
    ///
    /// https://datatracker.ietf.org/doc/draft-ietf-webtrans-http3/
    static var webTransportProtocol: Self {
        Self("WT-Protocol")!
    }
    /// WT-Available-Protocols
    ///
    /// https://datatracker.ietf.org/doc/draft-ietf-webtrans-http3/
    static var webTransportAvailableProtocols: Self {
        Self("WT-Available-Protocols")!
    }
}

#endif
