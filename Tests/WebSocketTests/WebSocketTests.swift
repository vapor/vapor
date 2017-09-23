import Core
import Dispatch
import TCP
import HTTP
import WebSocket
import XCTest

class WebSocketTests : XCTestCase {
    func testClientServer() throws {
        // FIXME: joannis, failing on linux
        return;
        let app = WebSocketApplication()
        let tcp = try TCP.Server()
        let server = HTTP.Server(tcp: tcp)
        
        server.drain { client in
            let parser = HTTP.RequestParser(queue: .global())
            let serializer = HTTP.ResponseSerializer()
            
            client.stream(to: parser)
                .stream(to: app.makeStream())
                .stream(to: serializer)
                .drain(into: client)
            
            client.tcp.start()
        }
        
        server.errorStream = { error in
            debugPrint(error)
        }
        
        try server.tcp.start(port: 8080)
        
        let promise0 = Promise<Void>()
        let promise1 = Promise<Void>()
        
        _ = try WebSocket.connect(to: "ws://0.0.0.0:8080/", queue: .global()).then { socket in
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
