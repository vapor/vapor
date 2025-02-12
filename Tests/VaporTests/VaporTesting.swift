import Vapor
import VaporTesting
import Testing

/// Tests to make sure Vapor's swift-testing integration works.
@Suite("Vapor Testing Tests")
struct VaporTestingTests {
    /// A test to trigger multiple Vapor+swift-testing integration functions to make sure they work at all.
    @Test("Test Vapor Testing functions")
    func contentContainerDecode() async throws {
        struct FooContent: Content, Equatable {
            var message: String = "hi"
        }
        struct FooDecodable: Decodable, Equatable {
            var message: String = "hi"
        }

        try await withApp { app in
            app.routes.post("decode") { req async throws -> String in
                #expect(try req.content.decode(FooContent.self) == FooContent())
                #expect(try req.content.decode(FooDecodable.self, as: .json) == FooDecodable())
                return "decoded!"
            }

            try await app.testing().test(.POST, "/decode") { req in
                try req.content.encode(FooContent())
            } afterResponse: { res in
                #expect(res.status == .ok)
                expectContains(res.body.string, "decoded!")
            }

            app.routes.post("decode-bad-header") { req async throws -> String in
                #expect(req.headers.contentType == .audio)
                #expect(
                    performing: {
                        try req.content.decode(FooContent.self)
                    }, throws: { error in
                        guard let abort = error as? Abort,
                              abort.status == .unsupportedMediaType else {
                            Issue.record("Unexpected error: \(error)")
                            return false
                        }
                        return true
                    }
                )
                #expect(try req.content.decode(FooDecodable.self, as: .json) == FooDecodable())
                return "decoded!"
            }

            try await app.testing().test(.POST, "/decode-bad-header") { req in
                try req.content.encode(FooContent())
                req.headers.contentType = .audio
            } afterResponse: { res in
                #expect(res.status == .ok)
                expectContains(res.body.string, "decoded!")
            }
        }
    }
}
