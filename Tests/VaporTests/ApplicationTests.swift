import Core
import HTTP
import Vapor
import TLS
import TCP
import XCTest

class ApplicationTests: XCTestCase {
    func testExample() throws {
        let server = try TCP.Server()
        let promise = Promise<Request>()
        
        let cert = FileManager.default.contents(atPath: "/Users/joannisorlandos/Desktop/server.crt.bin")!
        
        var clients = [AppleSSLServer]()
        
        server.drain { client in
            do {
                let client = AppleSSLServer(established: client.socket.descriptor, isNonBlocking: true, shouldReuseAddress: true)
                try client.initialize(certificate: cert)
                
                let parser = RequestParser(queue: .global())
                
                client.stream(to: parser).drain { request in
                    promise.complete(request)
                }
                
//                client.start(on: .global())
                clients.append(client)
            } catch {
                client.close()
            }
        }
        
        try server.start(port: 8081)
        print(try promise.future.blockingAwait())
    }
    
    func testHTTPSClient() throws {
        let queue = DispatchQueue(label: "test")
        
        let SSL = try AppleSSLClient()
        try SSL.connect(hostname: "google.com", port: 443).blockingAwait()
        try SSL.initialize(hostname: "google.com")
        
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
