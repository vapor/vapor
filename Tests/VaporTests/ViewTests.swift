import Vapor
import NIOCore
import VaporTesting
import Testing
import HTTPTypes
import RoutingKit
import Foundation

@Suite("View Tests")
struct ViewTests {
    @Test("Test returning a view as a response")
    func viewResponse() async throws {
        try await withApp { app in
            app.get("view") { req -> View in
                return View(data: Data("<h1>hello</h1>".utf8))
            }

            try await app.testing().test(.get, "/view") { res in
                #expect(res.status.code == 200)
                #expect(res.headers.contentType == .html)
                try #expect(await res.body.requireString() == "<h1>hello</h1>")
            }
        }
    }
}
