import Async
import Service
import Crypto
import Dispatch
import Foundation
import TCP
import HTTP
import TLS

extension WebSocket {
    /// Create a new WebSocket client in a future.
    ///
    /// The future will be completed with the WebSocket connection once the handshake using HTTP is complete.
    ///
    /// - parameter uri: The URI containing the remote host to connect to.
    /// - parameter worker: The Worker which this websocket will use for managing read and write operations
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/websocket/client/#connecting-a-websocket-client)
    public static func connect(
        to uri: URI,
        using container: Container
    ) throws -> WebSocket {
        guard
            uri.scheme == "ws" || uri.scheme == "wss",
            let hostname = uri.hostname,
            let port = uri.port ?? uri.defaultPort
        else {
            throw WebSocketError(.invalidURI)
        }
        
        if uri.scheme == "wss" {
            // FIXME: 
            fatalError()
//            let client = try container.make(TLSSocket.self, for: WebSocket.self)
//
//            DispatchSocketStream(client)
//
//            parser = client.output(to: HTTPResponseParser(maxSize: 50_000))
//
//            try client.connect(hostname: hostname, port: port).do {
//                client.finally {
//                    promise.fail(WebSocketError(.cannotConnect))
//                }
//
//                serializer.stream(to: client)
//
//                WebSocket.complete(to: promise, with: parser, id: id) {
//
//                }
//            }.catch(promise.fail)
//
//            serializer.onInput(request)
//
//            return WebSocket(socket: client, serverSide: false)
        } else {
            // Create a new socket to the host
            let socket = try TCPSocket()
            
            // The TCP Client that will be used by both HTTP and the WebSocket for communication
            let client = try TCPClient(socket: socket)

            let source = socket.source(on: container.eventLoop)
            let sink = socket.sink(on: container.eventLoop)
            let websocket = WebSocket(source: source, sink: sink, server: false)
            try client.connect(hostname: hostname, port: port)
            return websocket
        }
    }
    
    static func upgrade(response: HTTPResponse, id: String) throws {
        // Calculates the expected key
        let expectatedKey = Base64Encoder().encode(data: SHA1.hash(id + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"))
        
        let expectedKeyString = String(bytes: expectatedKey, encoding: .utf8) ?? ""
        
        // The server must accept the upgrade
        guard
            response.status == .upgrade,
            response.headers["Connection"] == "Upgrade",
            response.headers["Upgrade"] == "websocket"
        else {
            throw WebSocketError(.notUpgraded)
        }
        
        // Protocol version 13 uses `-Key` instead of `Accept`
        if response.headers["Sec-WebSocket-Version"] == "13",
            response.headers["Sec-WebSocket-Key"] == expectedKeyString {
        } else {
            // Fail if the handshake didn't return the expected accept-key
            guard response.headers["Sec-WebSocket-Accept"] == expectedKeyString else {
                throw WebSocketError(.notUpgraded)
            }
        }
    }
}
