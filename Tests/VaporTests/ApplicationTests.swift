import Async
import Bits
import HTTP
import Vapor
import TLS
import TCP
import XCTest

class ApplicationTests: XCTestCase {
    func testHTTPSClient() throws {
        try client(to: "google.com", port: 443)
    }
    
    func client(to host: String, port: UInt16) throws {
        #if os(macOS)
            let queue = DispatchQueue(label: "test")
            
            let clientSocket = try TCP.Socket()
            let client = TCP.Client(socket: clientSocket, queue: .global())
            let SSL = try AppleSSLSocket(socket: client)
            try clientSocket.connect(hostname: host, port: port).blockingAwait()
            try SSL.initializeClient(hostname: host)
            
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
        #endif
    }
    
    static let allTests = [
        ("testHTTPSClient", testHTTPSClient),
    ]
}
