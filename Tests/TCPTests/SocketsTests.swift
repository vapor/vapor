import Async
import Dispatch
import TCP
import XCTest

class SocketsTests: XCTestCase {
    func testServer() throws {
        let server = try TCPServer(eventLoops: [
            DispatchQueue(label: "codes.vapor.test.server")
        ])
        try server.start(port: 8338)

        /// 128 will be the max in flight clients
        server.stream(on: DispatchQueue(label: "accept")).drain(128) { client, serverReq in
            client.drain { buffer, clientReq in
                client.onInput(buffer)
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
                serverReq.requestOutput()
            }
        }.catch { err in
            XCTFail("\(err)")
        }.finally {
            // closed
        }

        let promise = Promise(Void.self)

        var completed = 0
        for _ in 0..<512 {
            let client = try TCPClient(on: DispatchQueue(label: "codes.vapor.test.client"))
            try client.connect(hostname: "localhost", port: 8338)
            let data = Data("hello".utf8)
            client.onInput(data.withByteBuffer { $0 })
            client.drain { buffer, req in
                completed += 1
                if completed == 512 {
                    DispatchQueue.global().async {
                        promise.complete()
                    }
                }
                client.stop()
            }.catch { err in
                XCTFail("\(err)")
            }.finally {
                // closed
            }
        }

        try DispatchQueue.global().sync {
            try promise.future.blockingAwait(timeout: .seconds(2))
        }

        server.stop()
    }

    static let allTests = [
        ("testServer", testServer),
    ]
}
