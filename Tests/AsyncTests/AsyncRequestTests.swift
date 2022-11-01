#if compiler(>=5.7) && canImport(_Concurrency)
import XCTVapor

fileprivate extension String {
    static func randomDigits(length: Int = 999) -> String {
        var string = ""
        for _ in 0...999 {
            string += String(Int.random(in: 0...9))
        }
        return string
    }
}

@available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
final class AsyncRequestTests: XCTestCase {
    
    func testStreamingRequest() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        
        let testValue = String.randomDigits()

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
