import Async
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
        worker: Worker
    ) throws -> Future<WebSocket> {
        guard
            uri.scheme == "ws" || uri.scheme == "wss",
            let hostname = uri.hostname,
            let port = uri.port ?? uri.defaultPort
        else {
            throw WebSocketError(.invalidURI)
        }
        
        // A promise that will be completed with a websocket if it doesn't fail
        let promise = Promise<WebSocket>()
        
        // Creates an HTTP client for the handshake
        let serializer = RequestSerializer()
        
        let parser: ResponseParser
        
        // Generates the UUID that will make up the WebSocket-Key
        let id = OSRandom().data(count: 16).base64EncodedString()
        
        // Create a basic HTTP Request, requesting an upgrade
        let request = Request(method: .get, uri: uri, headers: [
            "Host": uri.hostname ?? "",
            "Connection": "Upgrade",
            "Sec-WebSocket-Key": id,
            "Sec-WebSocket-Version": "13"
        ])
        
        if uri.scheme == "wss" {
            let client = try TLSClient(on: worker)
            
            parser = client.stream(to: ResponseParser(maxBodySize: 50_000))
            
            try client.connect(hostname: hostname, port: port).do {
                // Send the initial request
                let data = serializer.serialize(request)
                let bytes = data.withByteBuffer { $0 }
                client.onInput(bytes)
            }.catch(promise.fail)
            
            let websocket = WebSocket(socket: client, serverSide: false)
            
            WebSocket.complete(to: promise, with: parser, id: id, websocket: websocket)
        } else {
            // Create a new socket to the host
            let socket = try TCPSocket()
            try socket.connect(hostname: hostname, port: port)
            
            // The TCP Client that will be used by both HTTP and the WebSocket for communication
            let client = TCPClient(socket: socket, worker: worker)
            
            parser = client.stream(to: ResponseParser(maxBodySize: 50_000))
            
            client.socket.writable(queue: worker.eventLoop.queue).do {
                // Start reading in the client
                client.start()
                
                // Send the initial request
                let data = serializer.serialize(request)
                let bytes = data.withByteBuffer { $0 }
                client.onInput(bytes)
            }.catch(promise.fail)
            
            let websocket = WebSocket(socket: client, serverSide: false)
            
            WebSocket.complete(to: promise, with: parser, id: id, websocket: websocket)
        }
        
        return promise.future
    }
    
    fileprivate static func complete(to promise: Promise<WebSocket>, with parser: ResponseParser, id: String, websocket: WebSocket) {
        // Calculates the expected key
        let expectatedKey = Base64Encoder.encode(data: SHA1.hash(id + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"))
        
        let expectedKeyString = String(bytes: expectatedKey, encoding: .utf8) ?? ""
        
        // Sets up the handler for the handshake
        parser.drain { response in
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
                promise.complete(websocket)
            } else {
                // Fail if the handshake didn't return the expected accept-key
                guard response.headers["Sec-WebSocket-Accept"] == expectedKeyString else {
                    promise.fail(WebSocketError(.notUpgraded))
                    return
                }
                
                // Complete using the new websocket
                promise.complete(websocket)
            }
        }.catch { error in
            promise.fail(error)
        }
    }
}
