import Async
import Crypto
import Dispatch
import Foundation
import TCP
import HTTP

extension WebSocket {
    /// Create a new WebSocket client in a future.
    ///
    /// The future will be completed with the WebSocket connection once the handshake using HTTP is complete.
    ///
    /// - parameter uri: The URI containing the remote host to connect to.
    /// - parameter worker: The Worker which this websocket will use for managing read and write operations
    ///
    /// http://localhost:8000/websocket/client/#connecting-a-websocket-client
    public static func connect(
        to uri: URI,
        worker: Worker
    ) throws -> Future<WebSocket> {
        guard
            uri.scheme == "ws" || uri.scheme == "wss",
            let hostname = uri.hostname,
            let port = uri.port ?? uri.defaultPort
        else {
            throw WebSocketError(.invalidURI)
        }
        
        // Create a new socket to the host
        let socket = try TCP.Socket()
        try socket.connect(hostname: hostname, port: port)
        
        // The TCP Client that will be used by both HTTP and the WebSocket for communication
        let client = TCPClient(socket: socket, worker: worker)
        
        // TODO: TLS
        
        // A promise that will be completed with a websocket if it doesn't fail
        let promise = Promise<WebSocket>()
        
        // Creates an HTTP client for the handshake
        let serializer = RequestSerializer()
        let parser = ResponseParser(maxBodySize: 50_000)
        
        // Generates the UUID that will make up the WebSocket-Key
        let id = OSRandom().data(count: 16).base64EncodedString()
        
        // Create a basic HTTP Request, requesting an upgrade
        let request = Request(method: .get, uri: uri, headers: [
            "Host": uri.hostname ?? "",
            "Connection": "Upgrade",
            "Sec-WebSocket-Key": id,
            "Sec-WebSocket-Version": "13"
        ])

        // Calculates the expected key
        let expectatedKey = Base64Encoder.encode(data: SHA1.hash(id + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"))
        let expectedKeyString = String(bytes: expectatedKey, encoding: .utf8) ?? ""

        // Any errors in the handshake will cause the promise to fail
        serializer.errorNotification.handleNotification(callback: promise.fail)

        // Sets up the handler for the handshake
        client.stream(to: parser).drain { response in
            // The server must accept the upgrade
            guard
                response.status == .upgrade,
                response.headers["Connection"] == "Upgrade",
                response.headers["Upgrade"] == "websocket"
            else {
                promise.fail(WebSocketError(.notUpgraded))
                return
            }

            // Protocol version 13 uses `-Key` instead of `Accept`
            if response.headers["Sec-WebSocket-Version"] == "13",
                response.headers["Sec-WebSocket-Key"] == expectedKeyString {
                promise.complete(WebSocket(client: client, serverSide: false))
            } else {
                // Fail if the handshake didn't return the expected accept-key
                guard response.headers["Sec-WebSocket-Accept"] == expectedKeyString else {
                    promise.fail(WebSocketError(.notUpgraded))
                    return
                }

                // Complete using the new websocket
                promise.complete(WebSocket(client: client, serverSide: false))
            }
        }
        
        return client.socket.writable(queue: worker.queue).flatMap {
            // Start reading in the client
            client.start()
            
            // Send the initial request
            let data = serializer.serialize(request)
            client.inputStream(data)
            
            return promise.future
        }
    }
}
