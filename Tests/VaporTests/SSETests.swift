import XCTVapor
import AsyncHTTPClient

final class SSETests: XCTestCase {
    func testEndToEndUse() async throws {
        let app = Application()
        defer { app.shutdown() }
        
        let allEvents = ["hello\nworld", "1", "2", "3"]
        
        app.get("sse") { req in
            try await req.serverSentEvents { producer in
                for event in allEvents {
                    try await producer.sendEvent(.init(data: SSEValue(string: event)))
                }
            }
        }
        
        app.environment.arguments = ["serve"]
        try app.boot()
        try app.start()
        
        guard
            let localAddress = app.http.server.shared.localAddress,
            let port = localAddress.port
        else {
            XCTFail("couldn't get port from \(app.http.server.shared.localAddress.debugDescription)")
            return
        }
        
        let client = HTTPClient(eventLoopGroupProvider: .createNew)
        
        let request = HTTPClientRequest(url: "http://localhost:\(port)/sse")
        defer { _ = try? client.syncShutdown() }
        
        let events = try await client.execute(request, timeout: .seconds(1))
            .getServerSentEvents(allocator: app.allocator)
        
        var expectedEvents = allEvents
        for try await event in events {
            if expectedEvents.isEmpty {
                return XCTFail("Unexpected event received")
            }
                
            XCTAssertEqual(event.data.string, expectedEvents.removeFirst())
        }
        
        XCTAssertTrue(expectedEvents.isEmpty)
        
        // retain util the end
        _ = app
        _ = client
    }
}
