import Async
// import AppleSSL
import OpenSSL
import Bits
import TCP
import TLS
import XCTest

class SSLTests: XCTestCase {
    func testClientBlocking() { do { try _testClientBlocking() } catch { XCTFail("\(error)") } }
    func _testClientBlocking() throws {
        let tcpSocket = try TCPSocket(isNonBlocking: false)
        let tcpClient = try TCPClient(socket: tcpSocket)
        let tlsSettings = TLSClientSettings()
        let tlsClient = try OpenSSLClient(tcp: tcpClient, using: tlsSettings)
        try tlsClient.connect(hostname: "google.com", port: 443)
        try tlsClient.socket.handshake()
        let req = "GET /robots.txt HTTP/1.1\r\nContent-Length: 0\r\nHost: www.google.com\r\nUser-Agent: hi\r\n\r\n".data(using: .utf8)!
        _ = try tlsClient.socket.write(from: req.withByteBuffer { $0 })
        var res = Data(count: 4096)
        _ = try tlsClient.socket.read(into: res.withMutableByteBuffer { $0 })
        print(String(data: res, encoding: .ascii)!)
    }

    func testClient() { do { try _testClient() } catch { XCTFail("\(error)") } }
    func _testClient() throws {
        let tcpSocket = try TCPSocket(isNonBlocking: true)
        let tcpClient = try TCPClient(socket: tcpSocket)
        let tlsSettings = TLSClientSettings()
        // let tlsClient = try AppleTLSClient(tcp: tcpClient, using: tlsSettings)
        let tlsClient = try OpenSSLClient(tcp: tcpClient, using: tlsSettings)
        try tlsClient.connect(hostname: "google.com", port: 443)

        let exp = expectation(description: "read data")

        let tlsStream = tlsClient.socket.source(on: DispatchEventLoop(label: "codes.vapor.tls.client"))
        let tlsSink = tlsClient.socket.sink(on: DispatchEventLoop(label: "codes.vapor.tls.client"))
        
        tlsStream.drain { req in
            req.request(count: 1)
        }.output { buffer in
            let res = Data(buffer)
            XCTAssertTrue(String(data: res, encoding: .utf8)!.contains("User-agent: *"))
            exp.fulfill()
        }.catch { err in
            XCTFail("\(err)")
        }.finally {
            // closed
        }

        let source = EmitterStream(ByteBuffer.self)
        source.output(to: tlsSink)

        let req = "GET /robots.txt HTTP/1.1\r\nContent-Length: 0\r\nHost: www.google.com\r\nUser-Agent: hi\r\n\r\n".data(using: .utf8)!
        source.emit(req.withByteBuffer { $0 })

        waitForExpectations(timeout: 10)
    }

    static let allTests = [
        ("testClient", testClient)
    ]
}
