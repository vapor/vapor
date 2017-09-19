import Core
import HTTP
import Vapor
import TLS
import TCP
import XCTest

class ApplicationTests: XCTestCase {
    func testExample() throws {
        let server = try TCP.Server()
        
        let cert = FileManager.default.contents(atPath: "/Users/joannisorlandos/Desktop/server.crt.bin")!
        
        var clients = [AppleSSLPeer]()
        
        server.drain { client in
            do {
                let client = try AppleSSLPeer(socket: client.socket)
                try client.initialize(certificate: cert)
                
                let parser = RequestParser(queue: .global())
                let serializer = ResponseSerializer()
                
                serializer.drain { message in
                    message.message.withUnsafeBytes { (pointer: BytesPointer) in
                        client.inputStream(ByteBuffer(start: pointer, count: message.message.count))
                    }
                }
                
                client.stream(to: parser).drain { _ in
                    serializer.inputStream(Response())
                }
                
                client.start(on: .global())
                clients.append(client)
            } catch {
                client.close()
            }
        }
        
        try server.start(port: 8081)
        try client(to: "localhost", port: 8081)
    }
    
    func testHTTPSClient() throws {
        try client(to: "google.com", port: 443)
    }
    
    func client(to host: String, port: UInt16) throws {
        let queue = DispatchQueue(label: "test")
        
        let SSL = try AppleSSLClient()
        try SSL.connect(hostname: host, port: port).blockingAwait()
        try SSL.initialize(hostname: host)
        
        let parser = ResponseParser()
        let serializer = RequestSerializer()
        
        let promise = Promise<Response>()
        
        SSL.stream(to: parser).drain { response in
            promise.complete(response)
        }
        
        serializer.drain { message in
            message.message.withUnsafeBytes { (pointer: BytesPointer) in
                SSL.inputStream(ByteBuffer(start: pointer, count: message.message.count))
            }
        }
        
        SSL.start(on: queue)
        serializer.inputStream(Request())
        
        XCTAssertNoThrow(try promise.future.blockingAwait(timeout: .seconds(15)))
    }
    
    static let allTests = [
        ("testHTTPSClient", testHTTPSClient),
        ("testExample", testExample)
    ]
}
