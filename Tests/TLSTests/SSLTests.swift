import AppleSSL
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
        let tcpSocket = try TCPSocket(isNonBlocking: false)
        let tcpClient = try TCPClient(socket: tcpSocket)
        let tlsSettings = TLSClientSettings()
        let tlsClient = try AppleTLSClient(tcp: tcpClient, using: tlsSettings)
        print("connecting...")
        try tlsClient.connect(hostname: "vapor.codes", port: 443)
        print("initializing...")
        try tlsClient.socket.initialize()
        print("handshaking...")
        //
        try tlsClient.socket.handshake()
        print(tlsClient)
//        print("writing...")
//        let req = "GET / HTTP/1.1\r\nContent-Length: 0\r\nHost: httpbin.org\r\n\r\n".data(using: .utf8)!
//        try tlsClient.socket.write(max: req.count, from: req.withByteBuffer { $0 })
//
//        print("reading...")
//        var res = Data.init(count: 4096)
//        var buffer = MutableByteBuffer(start: res.withUnsafeMutableBytes { $0 }, count: 4096)
//        try tlsClient.socket.read(max: res.count, into: buffer)
//        print(res)
    }

    static let allTests = [
        ("testClient", testClient)
    ]
}
