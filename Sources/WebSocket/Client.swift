import Dispatch
import Core
import Crypto
import Foundation
import TCP
import HTTP

extension WebSocket {
    /// Create a new WebSocket client in a future.
    ///
    /// The future will be completed with the WebSocket connection once the handshake using HTTP is complete.
    ///
    /// - parameter hostname: The server's hostname to connect to
    /// - parameter port: The port to connect to, for HTTP
    /// - parameter uri: The URI is not officially part of the spec, but could route to a different API on the server
    /// - parameter queue: The queue on which this websocket will read and write
    public static func connect(
        hostname: String,
        port: UInt16 = 80,
        uri: URI = URI(path: "/"),
        worker: Worker
    ) throws -> Future<WebSocket> {
        // Create a new socket to the host
        let socket = try TCP.Socket()
        try socket.connect(hostname: hostname, port: port)
        
        // The TCP Client that will be used by both HTTP and the WebSocket for communication
        let client = TCP.Client(socket: socket, worker: worker)
        
        // A promise that will be completed with a websocket if it doesn't fail
        let promise = Promise<WebSocket>()
        
        // Creates an HTTP client for the handshake
        let serializer = RequestSerializer()
        let parser = ResponseParser()
        
        // Generates the UUID that will make up the WebSocket-Key
        let uuid = NSUUID().uuidString
        
        // Create a basic HTTP Request, requesting an upgrade
        let request = Request(method: .get, uri: uri, headers: [
            "Connection": "Upgrade",
            "Upgrade": "websocket",
            "Sec-WebSocket-Key": uuid,
            "Sec-WebSocket-Version": "13"
        ])

        // Calculates the expected key
        let expectatedKey = Base64Encoder.encode(data: SHA1.hash(uuid + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"))
        let expectedKeyString = String(bytes: expectatedKey, encoding: .utf8) ?? ""

        // Any errors in the handshake will cause the promise to fail
        serializer.errorStream = promise.fail

        // Sets up the handler for the handshake
        client.stream(to: parser).drain { response in
            // The server must accept the upgrade
            guard
                response.status == .upgrade,
                response.headers["Connection"] == "Upgrade",
                response.headers["Upgrade"] == "websocket"
            else {
                promise.fail(Error(.notUpgraded))
                return
            }

            // Protocol version 13 uses `-Key` instead of `Accept`
            if response.headers["Sec-WebSocket-Version"] == "13",
                response.headers["Sec-WebSocket-Key"] == expectedKeyString {
                promise.complete(WebSocket(client: client, serverSide: false))
            } else {
                // Fail if the handshake didn't return the expected accept-key
                guard response.headers["Sec-WebSocket-Accept"] == expectedKeyString else {
                    promise.fail(Error(.notUpgraded))
                    return
                }

                // Complete using the new websocket
                promise.complete(WebSocket(client: client, serverSide: false))
            }
        }

        // Start reading in the client
        client.start()

        // Send the initial request
        let data = serializer.serialize(request)
        client.inputStream(data)

        return promise.future
    }
}
