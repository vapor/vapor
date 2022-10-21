#if compiler(>=5.5) && canImport(_Concurrency)
import XCTVapor

@available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
final class AsyncRequestTests: XCTestCase {
    
    func testStreamingRequest() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        var testValue = ""
        for _ in 0...999 {
            testValue += String(Int.random(in: 0...9))
        }

        app.on(.POST, "stream", body: .stream) { req in
            var recievedBuffer = ByteBuffer()
            for try await part in req.body {
                XCTAssertNotNil(part)
                var part = part
                recievedBuffer.writeBuffer(&part)
            }
            let string = String(buffer: recievedBuffer)
            return string
        }

        try app.testable().test(.POST, "/stream", beforeRequest: { req in
            req.body = ByteBuffer(string: testValue)
        }) { res in
            XCTAssertEqual(res.status, .ok)
            let returnedString = try XCTUnwrap(try res.content.decode(String.self))
            XCTAssertEqual(testValue, returnedString)
        }
    }
}
#endif
