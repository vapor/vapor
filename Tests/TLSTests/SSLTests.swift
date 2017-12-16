import Async
// import AppleSSL
import Bits
import TCP
import TLS
import XCTest

class SSLTests: XCTestCase {
    func testClient() {
        do {
            try _testClient()
        } catch {
            XCTFail("\(error)")
        }
    }

    func _testClient() throws {
//        let tcpSocket = try TCPSocket(isNonBlocking: true)
//        let tcpClient = try TCPClient(socket: tcpSocket)
//        let tlsSettings = TLSClientSettings()
//        let tlsClient = try AppleTLSClient(tcp: tcpClient, using: tlsSettings)
//        try tlsClient.connect(hostname: "google.com", port: 443)
//
//        let exp = expectation(description: "read data")
//
//        let tlsStream = tlsClient.stream(on: DispatchQueue(label: "codes.vapor.tls.client"))
//        tlsStream.drain { req in
//            req.request(count: 1)
//        }.output { buffer in
//            let res = Data(buffer)
//            print(String(data: res, encoding: .utf8)!)
//            exp.fulfill()
//        }.catch { err in
//            XCTFail("\(err)")
//        }.finally {
//            // closed
//        }
//
//        let source = EmitterStream(ByteBuffer.self)
//        source.output(to: tlsStream)
//
//        let req = "GET /robots.txt HTTP/1.1\r\nContent-Length: 0\r\nHost: www.google.com\r\nUser-Agent: hi\r\n\r\n".data(using: .utf8)!
//        source.emit(req.withByteBuffer { $0 })
//
//        waitForExpectations(timeout: 5)
    }

    static let allTests = [
        ("testClient", testClient)
    ]
}
