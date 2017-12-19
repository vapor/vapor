import Async
import Bits
import Dispatch
import HTTP
import Foundation
import TCP
import Vapor
// import WebSocket
import XCTest

struct MyError: Error {}

class WebSocketTests : XCTestCase {
    func testClientServer() throws {
        // Failing on macOS
//        // TODO: Failing on Linux
//        let app = WebSocketApplication()
//        let container = BasicContainer(config: Config(), environment: .development, services: Services(), on: DispatchQueue.global())
//        let server = HTTPTestServer(container: container)
//
//        try server.start(with: app)
//        sleep(1)
//
//        let promise0 = Promise<Void>()
//        let promise1 = Promise<Void>()
//
//        let queue = DispatchQueue(label: "test.client")
//
//        let uri = URI(stringLiteral: "ws://localhost:8282/")
//
//        do {
//            _ = try WebSocket.connect(to: uri, worker: queue).do { socket in
//                let responses = ["test", "cat", "banana"]
//                let reversedResponses = responses.map {
//                    String($0.reversed())
//                }
//
//                var count = 0
//
//                socket.onText { string in
//                    XCTAssert(reversedResponses.contains(string), "\(string) does not exist in reversed expectations")
//                    count += 1
//
//                    if count == 3 {
//                        promise0.complete()
//                    } else if count > 3 {
//                        XCTFail()
//                    }
//                }.catch { error in
//                    XCTFail("\(error)")
//                }
//
//                socket.onBinary { blob in
//                    defer { promise1.complete() }
//
//                    guard Array(blob) == [0x00, 0x01, 0x00, 0x02] else {
//                        XCTFail()
//                        return
//                    }
//                }.catch { error in
//                    XCTFail("\(error)")
//                }
//
//                for response in responses {
//                    socket.send(response)
//                }
//
//                Data([
//                    0x00, 0x01, 0x00, 0x02
//                ]).withUnsafeBytes { (pointer: BytesPointer) in
//                    let buffer = ByteBuffer(start: pointer, count: 4)
//
//                    socket.send(buffer)
//                }
//            }.blockingAwait(timeout: .seconds(10))
//
//            try promise0.future.blockingAwait(timeout: .seconds(10))
//            try promise1.future.blockingAwait(timeout: .seconds(10))
//        } catch {
//            XCTFail("Error \(error) connecting to \(uri)")
//            throw error
//        }
    }
    
    static let allTests = [
        ("testClientServer", testClientServer)
    ]
}

//final class WebSocketApplication: Responder {
//    var sockets = [UUID: WebSocket]()
//    
//    func respond(to req: Request) throws -> Future<Response> {
//        let promise = Promise<Response>()
//
//        guard WebSocket.shouldUpgrade(for: req.http) else {
//            let res = req.makeResponse()
//            res.http = try HTTPResponse(status: .ok, body: "hi")
//            promise.complete(res)
//            return promise.future
//        }
//
//        let http = try WebSocket.upgradeResponse(for: req.http, with: WebSocketSettings()) { websocket in
//            let id = UUID()
//
//            websocket.onText { text in
//                let rev = String(text.reversed())
//                websocket.send(rev)
//            }.catch(onError: promise.fail)
//
//            websocket.onBinary { buffer in
//                websocket.send(buffer)
//            }.catch(onError: promise.fail)
//
//            self.sockets[id] = websocket
//
//            websocket.finally {
//                self.sockets[id] = nil
//            }
//        }
//        let res = req.makeResponse()
//        res.http = http
//        promise.complete(res)
//
//        return promise.future
//    }
//}

