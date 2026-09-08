import Vapor
import NIOCore
import VaporTesting
import Testing
import HTTPTypes
import RoutingKit

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

            try await app.testing { client in
                let res = try await client.get("/view")
                #expect(res.status.code == 200)
                #expect(res.headers.contentType == .html)
                try #expect(await res.body.requireString() == "<h1>hello</h1>")
            }
        }
    }
}
