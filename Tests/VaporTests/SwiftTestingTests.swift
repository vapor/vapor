import Testing
import Vapor
import VaporTesting

@Suite("Request Tests")
struct RequestTestsSwiftTesting {
    @Test("Test Redirect")
    func testRedirect() async throws {
        try await withApp { app in
            app.http.client.configuration.redirectConfiguration = .disallow

            app.get("redirect_normal") {
                $0.redirect(to: "foo", redirectType: .normal)
            }
            app.get("redirect_permanent") {
                $0.redirect(to: "foo", redirectType: .permanent)
            }
            app.post("redirect_temporary") {
                $0.redirect(to: "foo", redirectType: .temporary)
            }
            app.post("redirect_permanentPost") {
                $0.redirect(to: "foo", redirectType: .permanentPost)
            }

            try await app.server.start(address: .hostname("localhost", port: 0))

            guard let port = app.http.server.shared.localAddress?.port else {
                Issue.record("Failed to get port for app")
                return
            }

            #expect(try await app.client.get("http://localhost:\(port)/redirect_normal").status == .seeOther)
            #expect(try await app.client.get("http://localhost:\(port)/redirect_permanent").status == .movedPermanently)
            #expect(try await app.client.post("http://localhost:\(port)/redirect_temporary").status == .temporaryRedirect)
            #expect(try await app.client.post("http://localhost:\(port)/redirect_permanentPost").status == .permanentRedirect)

            await app.server.shutdown()
        }
    }
}
