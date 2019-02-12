//import Vapor
//import XCTest
//
//class WebSocketTests : XCTestCase {
//    func testClientServer() throws { }
//    
//    func testClientHeaders() throws {
//        let app = try Application()
//        
//        let group = MultiThreadedEventLoopGroup(numberOfThreads: 8)
//        
//        let ws = HTTPServer.webSocketUpgrader(shouldUpgrade: { req in
//            if req.url.path == "/deny" {
//                return nil
//            }
//            guard let _ = req.headers.bearerAuthorization else {
//                return nil
//            }
//            return [:]
//        }, onUpgrade: { ws, req in
//            ws.send(req.url.path)
//            ws.onText { ws, string in
//                ws.send(string.reversed())
//                if string == "close" {
//                    ws.close()
//                }
//            }
//            ws.onBinary { ws, data in
//                print("data: \(data)")
//            }
//            ws.onCloseCode { code in
//                print("code: \(code)")
//            }
//            ws.onClose.always {
//                print("closed")
//            }
//        })
//        
//        let server = try HTTPServer.start(
//            hostname: "127.0.0.1",
//            port: 8888,
//            responder: HelloResponder(),
//            upgraders: [ws],
//            on: group
//        ) { error in
//            XCTFail("\(error)")
//            }.wait()
//        
//        print(server)
//        let headers:HTTPHeaders = ["Authorization": "Bearer Test-Token"]
//        let req = Request(http: .init(method: .GET, url: "ws://127.0.0.1:8888", headers: headers), using: app)
//        
//        let _ = try app.client().container.make(WebSocketClient.self).webSocketConnect(req).wait()
//        // uncomment to test websocket server
//        //try server.onClose.wait()
//    }
//    
//    static let allTests = [
//        ("testClientServer", testClientServer),
//        ("testClientHeaders", testClientHeaders)
//    ]
//}
//
//struct HelloResponder: HTTPServerResponder {
//    func respond(to request: HTTPRequest, on worker: Worker) -> EventLoopFuture<HTTPResponse> {
//        let res = HTTPResponse(status: .ok, body: "This is a WebSocket server")
//        return worker.eventLoop.newSucceededFuture(result: res)
//    }
//}
