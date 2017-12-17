import Async
import Bits
import HTTP
import Foundation
import JunkDrawer
import TCP
import XCTest

struct EchoWorker: HTTPResponder, EventLoop {
    let queue: DispatchQueue = DispatchQueue(label: "codes.vapor.test.worker.echo")

    func respond(to req: HTTPRequest, on eventLoop: EventLoop) throws -> Future<HTTPResponse> {
        /// simple echo server
        return Future(.init(body: req.body))
    }
}

class HTTPServerTests: XCTestCase {
    func testTCP() throws {
        let tcpSocket = try TCPSocket(isNonBlocking: true)
        let tcpServer = try TCPServer(socket: tcpSocket)
        let server = HTTPServer(
            acceptStream: tcpServer.stream(
                on: DispatchQueue(label: "codes.vapor.http.test.server")
            ),
            workers: [EchoWorker()]
        )
        server.onError = { XCTFail("\($0)") }

        // beyblades let 'er rip
        try tcpServer.start(hostname: "localhost", port: 8123, backlog: 128)
        
        let exp = expectation(description: "all requests complete")
        var num = 1024
        for _ in 0..<num {
            let clientSocket = try TCPSocket(isNonBlocking: false)
            let client = TCPClient(socket: clientSocket)
            try client.connect(hostname: "localhost", port: 8123)
            let write = Data("GET / HTTP/1.1\r\nContent-Length: 0\r\n\r\n".utf8)
            _ = try client.socket.write(write)
            let read = try client.socket.read(max: 512)
            client.close()
            XCTAssertEqual(String(data: read, encoding: .utf8), "HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n")
            num -= 1
            if num == 0 {
                exp.fulfill()
            }
        }

        waitForExpectations(timeout: 5)
        tcpServer.stop()
    }

    static let allTests = [
        ("testTCP", testTCP),
    ]
}
