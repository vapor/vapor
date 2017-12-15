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

    func testStream() throws {
        var dataRequest: OutputRequest?
        var output: [Data] = []
        var parserStream: AnyInputStream?

        let byteStream = ClosureStream<ByteBuffer>(
            onInput: { buffer in
                output.append(Data(buffer))
            },
            onError: { error in
                XCTFail("\(error)")
            },
            onClose: { print("close") },
            onOutput: { req in
                dataRequest = req
            },
            onRequest: { count in print("count: \(count)") },
            onCancel: { print("cancel") },
            outputTo: { stream in
                parserStream = stream
            }
        )
        let client = HTTPClient(byteStream: byteStream)
        let req = HTTPRequest(method: .get, uri: "/html", headers: [.host: "httpbin.org"])
        let futureRes = client.send(req)

        XCTAssertEqual(output.count, 0)
        XCTAssertNotNil(dataRequest)
        dataRequest?.requestOutput()
        if output.count == 1 {
            let string = String(data: output[0], encoding: .utf8)!
            XCTAssertEqual(string, "GET /html HTTP/1.1\r\nHost: httpbin.org\r\nContent-Length: 0\r\n\r\n")
        } else {
            XCTFail("Invalid output count: \(output.count)")
        }

        "HTTP/1.1 137 TEST\r\nContent-Length: 0\r\n\r\n".data(using: .utf8)!.withByteBuffer(parserStream!.unsafeOnInput)
        let res = try futureRes.blockingAwait(timeout: .seconds(5))
        XCTAssertEqual(res.status.code, 137)
    }

    static let allTests = [
        ("testTCP", testTCP),
        ("testStream", testStream),
    ]
}
