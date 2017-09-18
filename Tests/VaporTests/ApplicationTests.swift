import Core
import HTTP
import Vapor
import TLS
import XCTest

class ApplicationTests: XCTestCase {
    func testHTTPSClient() throws {
        let queue = DispatchQueue(label: "test")
        
        let SSL = try AppleSSLClient()
        try SSL.connect(hostname: "google.com", port: 443).sync()
        try SSL.initializeSSLClient(hostname: "google.com")
        
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
        
        let response = try promise.future.sync(timeout: .seconds(15))
        print(response)
    }
    
    static let allTests = [
        ("testHTTPSClient", testHTTPSClient),
    ]
}
