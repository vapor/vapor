import Async
import Dispatch
import TCP
import XCTest

class SocketsTests: XCTestCase {
    func testServer() {
        do {
            try _testServer()
        } catch {
            XCTFail("\(error)")
        }
    }
    func _testServer() throws {
        let serverSocket = try TCPSocket(isNonBlocking: true)
        let server = try TCPServer(socket: serverSocket)

        /// 128 will be the max in flight clients
        let serverStream = server.stream(
            on: DispatchQueue(label: "codes.vapor.test.server"),
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
        )

        serverStream.drain(.max) { client, serverReq in
            let clientStream = client.0.stream(on: client.1)
            clientStream.drain { buffer, clientReq in
                /// simple echo server
                clientStream.onInput(buffer)
                /// after we write data, we are ready to read more
                /// note: important that we start reading here
                /// or else the source will not be active to detect
                /// the socket closing
                clientReq.requestOutput()
            }.catch { err in
                XCTFail("\(err)")
            }.finally {
                /// once the socket is closed, we are ready to tell
                /// the server to give us another client

                // we requested .max, so we will never run out
                // serverReq.requestOutput()
            }
        }.catch { err in
            XCTFail("\(err)")
        }.finally {
            // closed
        }
        try server.start(port: 8338)
        let exp = expectation(description: "all requests complete")

        var num = 1024
        for _ in 0..<num {
            let clientSocket = try TCPSocket(isNonBlocking: false)
            let client = try TCPClient(socket: clientSocket)
            try client.connect(hostname: "localhost", port: 8338)
            let write = Data("hello".utf8)
            _ = try client.socket.write(write)
            let read = try client.socket.read(max: 512)
            client.close()
            XCTAssertEqual(read, write)
            num -= 1
            if num == 0 {
                exp.fulfill()
            }
        }

        waitForExpectations(timeout: 5)
        server.stop()
    }

    static let allTests = [
        ("testServer", testServer),
    ]
}
