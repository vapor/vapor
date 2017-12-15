import Async
import Bits
import HTTP
import Foundation
import JunkDrawer
import TCP
import XCTest

class HTTPServerTests: XCTestCase {
    func testTCP() throws {
        let tcpSocket = try TCPSocket(isNonBlocking: true)
        let tcpServer = try TCPServer(socket: tcpSocket)
        let tcpStream = tcpServer.stream(
            on: DispatchQueue(label: "codes.vapor.http.test.server"),
            assigning: [
                DispatchQueue(label: "codes.vapor.test.worker.1"),
                DispatchQueue(label: "codes.vapor.test.worker.2"),
                DispatchQueue(label: "codes.vapor.test.worker.3"),
                DispatchQueue(label: "codes.vapor.test.worker.4"),
                DispatchQueue(label: "codes.vapor.test.worker.5"),
                DispatchQueue(label: "codes.vapor.test.worker.6"),
                DispatchQueue(label: "codes.vapor.test.worker.7"),
                DispatchQueue(label: "codes.vapor.test.worker.8"),
            ]
        ).map { client, eventLoop -> DispatchSocketStream<TCPSocket> in
            return client.stream(on: eventLoop)
        }

        let server = HTTPServer<
            DispatchSocketStream<TCPSocket>,
            MapStream<HTTPRequest, HTTPResponse>
        >(acceptStream: tcpStream) { byteStream in
            print(byteStream.eventLoop)
            return MapStream { (req: HTTPRequest) -> HTTPResponse in
                /// simple echo server
                return .init(body: req.body)
            }
        }
        print(server)
        
        // beyblades let 'er rip
        try tcpServer.start(hostname: "localhost", port: 8123, backlog: 128)
        // RunLoop.main.run()

        let exp = expectation(description: "all requests complete")
        var num = 1024
        for _ in 0..<num {
            let clientSocket = try TCPSocket(isNonBlocking: false)
            let client = try TCPClient(socket: clientSocket)
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
