import Async
import Dispatch
import HTTP
import TCP
import XCTest

class MiddlewareTests : XCTestCase {
    func testMiddleware() throws {
        let server = EmitterStream<Request>()

        let group = DispatchGroup()
        group.enter()
        let app = TestApp { req in
            XCTAssertEqual(req.headers["foo"], "bar")
            group.leave()
        }

        let middlewares = [TestMiddleware(), TestMiddleware()]
        let responder = middlewares
            .makeResponder(chainedto: app)
            .makeStream()

        group.enter()
        server.stream(to: responder).drain { res in
            XCTAssertEqual(res.headers["baz"], "bar")
            group.leave()
        }

        let req = Request()
        server.emit(req)
        group.wait()
    }
    
    func testClientServer() throws {
        let responder = HelloWorldResponder()
        
        let serverSocket = try TCP.Server()
        
        let server = HTTP.Server(clientStream: serverSocket)
        server.drain { peer in
            let parser = HTTP.RequestParser(worker: peer.tcp.worker)
            
            let responderStream = responder.makeStream()
            let serializer = HTTP.ResponseSerializer()
            
            peer.stream(to: parser)
                .stream(to: responderStream)
                .stream(to: serializer)
                .drain(into: peer)
            
            peer.tcp.start()
        }
        
        try serverSocket.start(port: 1234)
        
        let socket = try TCP.Socket()
        try socket.connect(hostname: "0.0.0.0", port: 1234)
        
        let tcpClient = TCPClient.init(socket: socket, worker: Worker(queue: .global()))
        let client = HTTPClient(tcp: tcpClient)
        tcpClient.start()
        
        let response = try client.send(request: Request()).blockingAwait()
        
        XCTAssertEqual(response.body.data, Data(responder.response.utf8))
    }

    static let allTests = [
        ("testMiddleware", testMiddleware)
    ]
}

/// Test application that passes all incoming
/// requests through a closure for testing
final class TestApp: Responder {
    let closure: (Request) -> ()

    init(closure: @escaping (Request) -> ()) {
        self.closure = closure
    }

    func respond(to req: Request) throws -> Future<Response> {
        closure(req)
        return Future(Response())
    }
}

/// Test middleware that sets req and res headers.
final class TestMiddleware: Middleware {
    func respond(to request: Request, chainingTo next: Responder) throws -> Future<Response> {
        request.headers["foo"] = "bar"

        let promise = Promise<Response>()

        try next.respond(to: request).then { res in
            res.headers["baz"] = "bar"
            promise.complete(res)
        }.catch { error in
            promise.fail(error)
        }

        return promise.future
    }
}
struct HelloWorldResponder: Responder, ExpressibleByStringLiteral {
    init(stringLiteral value: String) {
        self.response = value
    }
    
    init() {}
    
    var response = "Hello world"
    
    func respond(to req: Request) throws -> Future<Response> {
        let response = try Response(body: self.response)
        
        return Future(response)
    }
}

