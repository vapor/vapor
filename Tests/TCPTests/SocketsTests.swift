import Dispatch
import TCP
import XCTest

class SocketsTests : XCTestCase {
    func testConnect() throws {
        let socket = try Socket()
        try socket.connect(hostname: "google.com")

        let data = """
        GET / HTTP/1.1\r
        Host: google.com\r
        Content-Length: 2\r
        \r
        hi
        """.data(using: .utf8)!

        let queue = DispatchQueue(label: "codes.vapor.test")

        let read = socket.onWriteable(queue: queue) {
            _ = try! socket.write(data)
        }

        let group = DispatchGroup()
        group.enter()
        let write = socket.onReadable(queue: queue) {
            let response = try! socket.read(max: 8_192)

            let string = String(data: response, encoding: .utf8)
            XCTAssert(string?.contains("HTTP/1.0 400 Bad Request") == true)
            group.leave()
        }

        XCTAssertNotNil([read, write])
        group.wait()
    }

    func testBind() throws {
        let server = try Socket()
        try server.bind(hostname: "localhost", port: 8337)
        try server.listen()

        let queue = DispatchQueue(label: "codes.vapor.test")
        let group = DispatchGroup()
        group.enter()

        var accepted: (Socket, DispatchSourceRead)?

        let read = server.onReadable(queue: queue) {
            let client = try! server.accept()
            let read = client.onReadable(queue: queue) {
                let data = try! client.read(max: 8_192)
                XCTAssertEqual(String(data: data, encoding: .utf8), "hello")
                group.leave()
            }
            accepted = (client, read)
            XCTAssertNotNil(accepted)
        }
        XCTAssertNotNil(read)

        do {
            let client = try Socket(isNonBlocking: false)
            try client.connect(hostname: "localhost", port: 8337)
            let data = "hello".data(using: .utf8)!
            _ = try! client.write(data)
        }

        group.wait()
    }

    static let allTests = [
        ("testConnect", testConnect)
    ]
}
