import Vapor
import NIOCore
import VaporTesting
import Testing

@Suite("View Tests")
struct ViewTests {
    @Test("Test returning a view as a response")
    func viewResponse() async throws {
        try await withApp { app in
            app.get("view") { req -> View in
                var data = ByteBufferAllocator().buffer(capacity: 0)
                data.writeString("<h1>hello</h1>")
                return View(data: data)
            }

            try await app.testing().test(.get, "/view") { res async in
                #expect(res.status.code == 200)
                #expect(res.headers.contentType == .html)
                #expect(res.body.string == "<h1>hello</h1>")
            }
        }
    }
}
