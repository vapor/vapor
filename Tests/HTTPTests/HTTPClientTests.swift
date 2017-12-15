import Async
import Bits
import HTTP
import Foundation
import TCP
import XCTest

class HTTPClientTests: XCTestCase {
    func testTCP() throws {
        let tcpSocket = try TCPSocket(isNonBlocking: true)
        let tcpClient = try TCPClient(socket: tcpSocket)
        try tcpClient.connect(hostname: "httpbin.org", port: 80)
        let tcpStream = tcpSocket.stream(on: DispatchQueue(label: "codes.vapor.http.test.client"))
        let client = HTTPClient(byteStream: tcpStream)

        let req = HTTPRequest(method: .get, uri: "/html", headers: [.host: "httpbin.org"])
        let res = client.send(req)

        let exp = expectation(description: "response")
        res.do { res in
            XCTAssertTrue(String(data: res.body.data!, encoding: .utf8)!.contains("Moby-Dick"))
            XCTAssertEqual(res.body.count, 3741)
            exp.fulfill()
        }.catch { error in
            XCTFail("\(error)")
        }

        waitForExpectations(timeout: 5)
    }

    static let allTests = [
        ("testTCP", testTCP),
    ]
}
