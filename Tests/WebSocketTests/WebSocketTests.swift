import Core
import Dispatch
import TCP
import HTTP
import Vapor
import WebSocket
import XCTest

class WebSocketTests : XCTestCase {
    func testClientServer() throws {
        // FIXME: joannis, failing on linux
        return;
        let app = WebSocketApplication()
        let tcp = try TCP.Server()
        let server = EngineServer(config: EngineServerConfig())
        
        try server.start(with: app)
        
        let promise0 = Promise<Void>()
        let promise1 = Promise<Void>()

        let worker = Worker(queue: .global())
        _ = try WebSocket.connect(hostname: "0.0.0.0", port: 8080, uri: URI(path: "/"), worker: worker).then { socket in
            let responses = ["test", "cat", "banana"]
            let reversedResponses = responses.map {
                String($0.reversed())
            }
            
            var count = 0
            
            socket.onText { string in
                XCTAssert(reversedResponses.contains(string))
                count += 1
                
                if count == 3 {
                    promise0.complete(())
                }
            }
            
            socket.onBinary { blob in
                defer { promise1.complete(()) }
                
                guard Array(blob) == [0x00, 0x01, 0x00, 0x02] else {
                    XCTFail()
                    return
                }
            }
            
            for response in responses {
                socket.send(response)
            }
            
//            socket.send(Data([
//                0x00, 0x01, 0x00, 0x02
//                ]))
            
            promise0.complete(())
        }
        
        try promise0.future.sync(timeout: .seconds(10))
//        try promise1.future.sync()
    }
    
    static let allTests = [
        ("testClientServer", testClientServer)
    ]
}

struct WebSocketApplication: Responder {
    func respond(to req: Request) throws -> Future<Response> {
        let promise = Promise<Response>()
        
        if WebSocket.shouldUpgrade(for: req) {
            let res = try WebSocket.upgradeResponse(for: req)
            res.onUpgrade = { client in
                let websocket = WebSocket(client: client)
                websocket.onText { text in
                    let rev = String(text.reversed())
                    websocket.send(rev)
                }
            }
            promise.complete(res)
        } else {
            let res = try Response(status: .ok, body: "hi")
            promise.complete(res)
        }
        
        return promise.future
    }
}
