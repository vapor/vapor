import XCTVapor
import XCTest
import Vapor
import NIOCore

fileprivate extension String {
    static func randomDigits(length: Int = 999) -> String {
        var string = ""
        for _ in 0...999 {
            string += String(Int.random(in: 0...9))
        }
        return string
    }
}

final class AsyncRequestTests: XCTestCase {
    
    func testStreamingRequest() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        
        let testValue = String.randomDigits()

        app.on(.POST, "stream", body: .stream) { req -> String in
            var recievedBuffer = ByteBuffer()
            for try await part in req.body {
                XCTAssertNotNil(part)
                var part = part
                recievedBuffer.writeBuffer(&part)
            }
            return String(buffer: recievedBuffer)
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
