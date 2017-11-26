import Async
import Dispatch
import TCP
import XCTest

class SocketsTests: XCTestCase {
    func testServer() throws {
        let server = try TCPServer()
        try server.start(port: 8338)
        let promise = Promise<Void>()
        
        server.drain { client in
            client.drain { buffer in
                XCTAssertEqual(String(bytes: buffer, encoding: .utf8), "hello")
                promise.complete(())
            }.catch(onError: promise.fail)
            
            client.start()
        }.catch(onError: promise.fail)
        
        try clientHello(port: 8338)
        try promise.future.blockingAwait(timeout: .seconds(3))
    }

    static let allTests = [
        ("testServer", testServer),
    ]
}

fileprivate func clientHello(port: UInt16) throws {
    do {
        let client = try TCPSocket(isNonBlocking: false)
        try client.connect(hostname: "localhost", port: port)
        let data = "hello".data(using: .utf8)!
        _ = try! client.write(data)
    }
}
