import Async
import Bits
import Core
import Foundation
import Dispatch
import TCP
import HTTP
import WebSocket
import XCTest

final class HTTPTestServer {
    /// Host name the server will bind to.
    public let hostname: String
    
    /// Port the server will bind to.
    public let port: UInt16
    
    /// Listen backlog.
    public let backlog: Int32
    
    /// Number of client accepting workers.
    /// Should be equal to the number of logical cores.
    public let workerCount: Int
    
    /// Creates a new engine server config
    public init(
        hostname: String = "0.0.0.0",
        port: UInt16 = 8282,
        backlog: Int32 = 4096,
        workerCount: Int = 2
    ) {
        self.hostname = hostname
        self.port = port
        self.workerCount = workerCount
        self.backlog = backlog
    }
    
    /// Start the server. Server protocol requirement.
    public func start(with responder: Responder) throws {
        // create a tcp server
        let socket = try TCPSocket(isNonBlocking: false)
        let tcp = TCPServer(socket: socket, eventLoopCount: workerCount)
        let server = HTTPServer(socket: tcp)
        
        // setup the server pipeline
        server.drain { client in
            let parser = HTTP.RequestParser(on: client.tcp.worker, maxBodySize: 100_000)
            let responderStream = responder.makeStream()
            let serializer = HTTP.ResponseSerializer()
            
            client.stream(to: parser)
                .stream(to: responderStream)
                .stream(to: serializer)
                .drain { data in
                    client.onInput(data)
                    serializer.upgradeHandler?(client.tcp)
                }.catch { XCTFail("\($0)") }
            
            client.tcp.start()
        }.catch { XCTFail("\($0)") }
        
        // bind, listen, and start accepting
        try tcp.start(
            hostname: hostname,
            port: port,
            backlog: backlog
        )
    }
}

struct MyError: Error {}

class WebSocketTests : XCTestCase {
    func testClientServer() throws {
        // TODO: Failing on Linux
        let app = WebSocketApplication()
        let server = HTTPTestServer()
        
        try server.start(with: app)
        sleep(1)
        
        let promise0 = Promise<Void>()
        let promise1 = Promise<Void>()
        
        let queue = DispatchQueue(label: "test.client")
        
        let uri = URI(stringLiteral: "ws://localhost:8282/")
        
        do {
            _ = try WebSocket.connect(to: uri, worker: queue).do { socket in
                let responses = ["test", "cat", "banana"]
                let reversedResponses = responses.map {
                    String($0.reversed())
                }
                
                var count = 0
                
                socket.onText { string in
                    XCTAssert(reversedResponses.contains(string), "\(string) does not exist in reversed expectations")
                    count += 1
                    
                    if count == 3 {
                        promise0.complete()
                    } else if count > 3 {
                        XCTFail()
                    }
                }.catch { error in
                    XCTFail("\(error)")
                }
                
                socket.onBinary { blob in
                    defer { promise1.complete() }
                    
                    guard Array(blob) == [0x00, 0x01, 0x00, 0x02] else {
                        XCTFail()
                        return
                    }
                }.catch { error in
                    XCTFail("\(error)")
                }
                
                for response in responses {
                    socket.send(response)
                }
                
                Data([
                    0x00, 0x01, 0x00, 0x02
                ]).withUnsafeBytes { (pointer: BytesPointer) in
                    let buffer = ByteBuffer(start: pointer, count: 4)
                    
                    socket.send(buffer)
                }
            }.blockingAwait(timeout: .seconds(10))
            
            try promise0.future.blockingAwait(timeout: .seconds(10))
            try promise1.future.blockingAwait(timeout: .seconds(10))
        } catch {
            XCTFail("Error \(error) connecting to \(uri)")
            throw error
        }
    }
    
    static let allTests = [
        ("testClientServer", testClientServer)
    ]
}

final class WebSocketApplication: Responder {
    var sockets = [UUID: WebSocket]()
    
    func respond(to req: Request) throws -> Future<Response> {
        let promise = Promise<Response>()

        guard WebSocket.shouldUpgrade(for: req) else {
            let res = try Response(status: .ok, body: "hi")
            promise.complete(res)
            return promise.future
        }

        let res = try WebSocket.upgradeResponse(for: req, with: WebSocketSettings()) { request, websocket in
            let id = UUID()

            websocket.onText { text in
                let rev = String(text.reversed())
                websocket.send(rev)
                }.catch(onError: promise.fail)

            websocket.onBinary { buffer in
                websocket.send(buffer)
                }.catch(onError: promise.fail)

            self.sockets[id] = websocket

            websocket.finally {
                self.sockets[id] = nil
            }
        }
        promise.complete(res)

        return promise.future
    }
}
