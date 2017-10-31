import Async
import Dispatch
import TCP
import XCTest

class SocketsTests: XCTestCase {
    func testConnect() throws {
        let socket = try Socket()
        try socket.connect(hostname: "google.com", port: 80)

        let data = """
        GET / HTTP/1.1\r
        Host: google.com\r
        Content-Length: 2\r
        \r
        hi
        """.data(using: .utf8)!

        let queue = DispatchQueue(label: "codes.vapor.test")

        let write = DispatchSource.makeWriteSource(fileDescriptor: socket.descriptor, queue: queue)
        write.setEventHandler {
            _ = try! socket.write(data)
        }
        write.resume()
        
        let promise = Promise<Void>()

        let read = DispatchSource.makeReadSource(fileDescriptor: socket.descriptor, queue: queue)
        read.setEventHandler {
            let response = try! socket.read(max: 8_192)

            let string = String(data: response, encoding: .utf8)
            XCTAssert(string?.contains("HTTP/1.0 400 Bad Request") == true, "Response \(response) did not contain the expected 'HTTP/1.0 400 Bad Request'")
            promise.complete(())
        }
        read.resume()

        XCTAssertNotNil([read, write])
        try promise.future.blockingAwait(timeout: .seconds(3))
    }

    func testBind() throws {
        let server = try Socket()
        try server.bind(hostname: CurrentHost.hostname, port: 8337)
        try server.listen()

        let queue = DispatchQueue(label: "codes.vapor.test")
        let promise = Promise<Void>()

        var accepted: (Socket, DispatchSourceRead)?

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
            
            accepted = (client, read)
            XCTAssertNotNil(accepted)
            XCTAssert(
                client.address?.remoteAddress == "127.0.0.1" || client.address?.remoteAddress == "0.0.0.0" || client.address?.remoteAddress == "::1",
                "\(client.address?.remoteAddress ?? "nil") was not localhost or an alias"
            )
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
