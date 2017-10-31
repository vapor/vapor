import Async
import Dispatch
import TCP
import XCTest

class SocketsTests: XCTestCase {
    func testBind() throws {
        let server = try Socket()
        try server.bind(hostname: CurrentHost.hostname, port: 8337)
        try server.listen()

        let queue = DispatchQueue(label: "codes.vapor.test")
        let promise = Promise<Void>()
        
        let read = DispatchSource.makeReadSource(fileDescriptor: server.descriptor, queue: queue)
        read.setEventHandler {
            let client = try! server.accept()
            let read = DispatchSource.makeReadSource(
                fileDescriptor: client.descriptor,
                queue: queue
            )
            read.setEventHandler {
                let data = try! client.read(max: 8_192)
                XCTAssertEqual(String(data: data, encoding: .utf8), "hello")
                promise.complete(())
            }
            read.resume()
        }
        read.resume()

        do {
            let client = try Socket(isNonBlocking: false)
            try client.connect(hostname: CurrentHost.hostname, port: 8337)
            let data = "hello".data(using: .utf8)!
            _ = try! client.write(data)
        }
        
        try promise.future.blockingAwait(timeout: .seconds(3))
    }
    
    func testServer() throws {
        let server = try Server()
        try server.start(port: 8338)
        let promise = Promise<Void>()
        
        server.drain { client in
            client.drain { buffer in
                XCTAssertEqual(String(bytes: buffer, encoding: .utf8), "hello")
                promise.complete(())
            }
            
            client.start()
        }
        
        try clientHello(port: 8338)
        try promise.future.blockingAwait(timeout: .seconds(3))
    }

    static let allTests = [
        ("testConnect", testConnect),
        ("testBind", testBind),
        ("testServer", testServer),
    ]
}

fileprivate func clientHello(port: UInt16) throws {
    do {
        let client = try Socket(isNonBlocking: false)
        try client.connect(hostname: "localhost", port: port)
        let data = "hello".data(using: .utf8)!
        _ = try! client.write(data)
    }
}
