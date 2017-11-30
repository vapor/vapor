import Foundation
import HTTP

public struct WebSocketSettings {
    public typealias SubProtocolTransformer = ([String]) throws -> String?

    // public var maxPacketSize: Int = Int(UInt16.max)
    public var requireSSL: Bool = false
    
    /// The maximum accepted payload size (to prevent memory attacks)
    var maximumPayloadSize: Int = 1_000_000
    
    public var subProtocols: SubProtocolTransformer = { requestProtocols in
        guard !requestProtocols.isEmpty else { return nil }
        return requestProtocols.first
    }

    /// empty initialiser for defaults
    public init() { }

    func apply(on request: Request) throws {
        guard requireSSL else { return }

        // TODO is there a better way of checking if the request is over ssl?
        if let hostname = request.uri.hostname,
            hostname.isSecure {
            return
        }

        throw WebSocketError(.invalidURI)
    }

    func apply(on response: Response, request: Request) throws {
        try applySubProtocol(on: response, request)
    }

    func apply(on websocket: WebSocket, request: Request, response: Response) throws {
        websocket.connection.parser.maximumPayloadSize = self.maximumPayloadSize
    }

    private func applySubProtocol(on response: Response, _ request: Request) throws {
        let requestSubProtocols = getSubProtocols(from: request)
        if let responseSubProtocol = try subProtocols(requestSubProtocols) {
            response.headers[.secWebSocketProtocol] = responseSubProtocol
        }
    }

    private func getSubProtocols(from request: Request) -> [String] {
        return request.headers[.secWebSocketProtocol]?.components(separatedBy: ", ") ?? []
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
