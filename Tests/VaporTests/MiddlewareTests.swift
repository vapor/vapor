import Async
import Bits
import Dispatch
import HTTP
import TCP
import Vapor
import XCTest

class MiddlewareTests : XCTestCase {
    func testMiddleware() throws {
//        let server = EmitterStream<Request>()
//
//        let group = DispatchGroup()
//        group.enter()
//        let closure = TestApp { req in
//            XCTAssertEqual(req.http.headers["foo"], "bar")
//            group.leave()
//        }
//
//        let app = try Application()
//
//        let middlewares = [TestMiddleware(), TestMiddleware()]
//        let r = middlewares
//            .makeResponder(chainedto: closure)
//        let responder = ResponderStream(responder: r, on: app, using: app)
//
//        group.enter()
//        server.stream(to: responder).drain { res in
//            XCTAssertEqual(res.headers["baz"], "bar")
//            group.leave()
//        }.catch { XCTFail("\($0)") }
//
//        let req = Request(on: app, using: app)
//        server.emit(req)
//        group.wait()
    }

    func testClientServer() throws {
//        let responder = HelloWorldResponder()
//
//        let serverSocket = try TCPServer()
//        let server = HTTPServer(socket: serverSocket)
//        server.drain { peer in
//            let parser = HTTP.RequestParser(on: peer.tcp.worker, maxSize: 100_000)
//
//            let responderStream = responder.makeStream()
//            let serializer = HTTP.ResponseSerializer()
//
//            peer.stream(to: parser)
//                .stream(to: responderStream)
//                .stream(to: serializer)
//                .stream(to: peer)
//
//            peer.tcp.start()
//        }.catch { XCTFail("\($0)") }
//
//        try serverSocket.start(port: 1234)
//
//        var socket = try TCPSocket()
//        try socket.connect(hostname: "0.0.0.0", port: 1234)
//
//        let tcpClient = TCPClient.init(socket: socket, worker: Worker(queue: .global()))
//        let client = HTTPClient(socket: tcpClient)
//        tcpClient.start()
//
//        let response = try client.send(request: Request()).blockingAwait(timeout: .seconds(3))
//
//        try response.body.withUnsafeBytes { (pointer: BytesPointer) in
//            let buffer = ByteBuffer(start: pointer, count: response.body.count ?? 0)
//            XCTAssertEqual(Data(buffer), Data(responder.response.utf8))
//        }
    }

    static let allTests = [
        ("testMiddleware", testMiddleware),
        ("testClientServer", testClientServer)
    ]
}

///// Test application that passes all incoming
///// requests through a closure for testing
//final class TestApp: Responder {
//    let closure: (Request) -> ()
//
//    init(closure: @escaping (Request) -> ()) {
//        self.closure = closure
//    }
//
//    func respond(to req: Request) throws -> Future<Response> {
//        closure(req)
//        return Future(Response())
//    }
//}

/// Test middleware that sets req and res headers.
//final class TestMiddleware: Middleware {
//    func respond(to request: Request, chainingTo next: Responder) throws -> Future<Response> {
//        request.headers["foo"] = "bar"
//
//        let promise = Promise<Response>()
//
//        try next.respond(to: request).do { res in
//            res.headers["baz"] = "bar"
//            promise.complete(res)
//        }.catch { error in
//            promise.fail(error)
//        }
//
//        return promise.future
//    }
//}
//struct HelloWorldResponder: Responder, ExpressibleByStringLiteral {
//    init(stringLiteral value: String) {
//        self.response = value
//    }
//    
//    init() {}
//    
//    var response = "Hello world"
//    
//    func respond(to req: Request) throws -> Future<Response> {
//        let response = try Response(body: self.response)
//        
//        return Future(response)
//    }
//}

