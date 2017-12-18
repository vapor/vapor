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

        let worker = DispatchEventLoop(label: "codes.vapor.test.worker.1")
        let serverStream = server.stream(
            on: DispatchEventLoop(label: "codes.vapor.test.server")
        )

        /// set up the server stream
        serverStream.drain { req in
            req.request(count: .max)
        }.output { client in
            let clientSource = client.socket.source(on: worker)
            let clientSink = client.socket.sink(on: worker)
            
            var clientReq: ConnectionContext?
            clientSource.drain { req in
                clientReq = req
                clientReq!.request()
            }.output { buffer in
                /// simple echo server
                clientSink.next(buffer)
                /// after we write data, we are ready to read more
                /// note: important that we start reading here
                /// or else the source will not be active to detect
                /// the socket closing
                clientReq!.request()
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

        // beyblades let 'er rip
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
