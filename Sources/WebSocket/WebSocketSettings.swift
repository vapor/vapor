import Foundation
import TLS
import HTTP

public struct WebSocketSettings {
    public typealias SubProtocolTransformer = ([String]) throws -> String?

    // TODO how can I set the packet size?
    // public var maxPacketSize: Int = Int(UInt16.max)
    public var sslSettings: TLSClientSettings?
    public var subProtocols: SubProtocolTransformer = { requestProtocols in
        guard !requestProtocols.isEmpty else { return nil }
        return requestProtocols.first
    }

    /// empty initialiser for defaults
    public init() { }

    func apply(on request: HTTPRequest) throws {
        guard let _ = sslSettings else { return }

        // TODO is there a better way of checking if the request is over ssl?
        if request.uri.hostname?.isSecure == true {
            return
        }

        throw WebSocketError(.invalidURI)
    }

    func apply(on response: inout HTTPResponse, request: HTTPRequest) throws {
        try applySubProtocol(on: &response, request)
    }

    func apply(on websocket: WebSocket, request: HTTPRequest, response: HTTPResponse) throws {
        // TODO apply maxPacketSize on the WebSocket?
    }

    private func applySubProtocol(on response: inout HTTPResponse, _ request: HTTPRequest) throws {
        let requestSubProtocols = getSubProtocols(from: request)
        if let responseSubProtocol = try subProtocols(requestSubProtocols) {
            response.headers[.secWebSocketProtocol] = responseSubProtocol
        }
    }

    private func getSubProtocols(from request: HTTPRequest) -> [String] {
        return request.headers[.secWebSocketProtocol]?.components(separatedBy: ", ") ?? []
    }
}

extension String {
    var isSecure: Bool {
        return self == "https" || self == "wss"
    }
}

extension WebSocketSettings: ExpressibleByArrayLiteral {
    public typealias ArrayLiteralElement = String

    public init(arrayLiteral elements: ArrayLiteralElement...) {
        self.subProtocols = { requestProtocols in
            return try SubProtocolMatcher(request: requestProtocols, router: elements).matching()
        }
    }
}
