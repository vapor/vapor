#if UnstableWebTransport

import HTTPTypes
import RawStructuredFieldValues
public import RoutingKit

extension RoutesBuilder {
    /// Adds a route for handling WebTransport over HTTP/3 sessions.
    ///
    /// - Parameters:
    ///   - path: The path components of the WebTransport route.
    ///   - availableProtocols: The list of application protocols supported by the server.
    ///   - requireProtocolNegotiation: A Boolean value indicating whether Application Protocol Negotiation is required.
    ///   - closure: The closure where WebTransport operations using the session are performed.
    ///
    /// - Returns: ``Route`` instance for the newly created WebTransport over HTTP/3 endpoint.
    @discardableResult
    public func webTransport(
        _ path: PathComponent...,
        availableProtocols: [String] = [],
        requireProtocolNegotiation: Bool = false,
        session closure: @Sendable @escaping (consuming WebTransportSession) async throws -> Void
    ) -> Route {
        self.webTransport(
            path,
            availableProtocols: availableProtocols,
            requireProtocolNegotiation: requireProtocolNegotiation,
            session: closure
        )
    }

    /// Adds a route for handling WebTransport over HTTP/3 sessions.
    ///
    /// - Parameters:
    ///   - path: The path components of the WebTransport route.
    ///   - availableProtocols: The list of application protocols supported by the server.
    ///   - requireProtocolNegotiation: A Boolean value indicating whether Application Protocol Negotiation is required.
    ///   - closure: The closure where WebTransport operations using the session are performed.
    ///
    /// - Returns: ``Route`` instance for the newly created WebTransport over HTTP/3 endpoint.
    @discardableResult
    public func webTransport(
        _ path: [PathComponent],
        availableProtocols: [String] = [],
        requireProtocolNegotiation: Bool = false,
        session closure: @Sendable @escaping (consuming WebTransportSession) async throws -> Void
    ) -> Route {
        self.on(.connect, path) { request -> Response in
            guard request.extendedConnectProtocol == "webtransport-h3" || request.extendedConnectProtocol == "webtransport" else {
                throw Abort(.forbidden)
            }
            var applicationProtocol: String?
            if !availableProtocols.isEmpty,
                let wtAvailableProtocols = request.headers[values: .webTransportAvailableProtocols].first
            {
                var headerParser = StructuredFieldValueParser(Array(wtAvailableProtocols.utf8))
                if let list = try? headerParser.parseListFieldValue() {
                    for itemOrInnerList in list {
                        guard
                            case .item(let item) = itemOrInnerList,
                            case .string(let wtProtocol) = item.rfc9651BareItem
                        else {
                            continue
                        }
                        if availableProtocols.contains(wtProtocol) {
                            applicationProtocol = wtProtocol
                            break
                        }
                    }
                }
            }
            guard applicationProtocol != nil || !requireProtocolNegotiation else {
                throw Abort(.forbidden)
            }
            var responseHeaders = HTTPFields()
            if let applicationProtocol {
                var headerSerializer = StructuredFieldValueSerializer()
                responseHeaders.append(
                    .init(
                        name: .webTransportProtocol,
                        value: try headerSerializer.writeItemFieldValue(
                            .init(bareItem: RFC9651BareItem.string(applicationProtocol), parameters: [:])
                        )
                    )
                )
            }
            return Response(
                status: .ok,
                headers: responseHeaders,
                webTransportSession: closure,
                webTransportApplicationProtocol: applicationProtocol
            )
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
