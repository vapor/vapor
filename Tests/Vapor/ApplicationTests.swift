import XCTest
@testable import Vapor

class ApplicationTests: XCTestCase {
    static let allTests = [
        ("testMediaType", testMediaType),
        ("testProviders", testProviders),
        ("testProvidersOverride", testProvidersOverride),
    ]

    var workDir: String {
        let parent = #file.characters.split(separator: "/").map(String.init).dropLast().joined(separator: "/")
        let path = "/\(parent)/../../Sources/Development/"
        return path
    }

    /**
        Ensures requests to files like CSS
        files have appropriate "Content-Type"
        headers returned.
    */
    func testMediaType() throws {
        let app = Application(workDir: workDir)

        let request = try Request(method: .get, uri: "/styles/app.css")

        guard let response = try? app.respond(to: request) else {
            XCTFail("App could not respond")
            return
        }

        var found = false
        for header in response.headers {
            guard header.key == "Content-Type" else { continue }
            guard header.value == "text/css" else { continue }
            found = true
        }

        XCTAssert(found, "CSS Content Type not found")
    }

    /**
        Tests to make sure Providers
        are properly overriding properties
        on the Application and that the boot
        method is being called.
    */
    func testProviders() {
        final class TestServer: Server {
            init(host: String, port: Int, securityLayer: SecurityLayer) {}
            func start(responder: Responder, errors: ServerErrorHandler) throws {}
        }

        class TestProvider: Provider {
            var bootRan = false

            func boot(with application: Application) {
                bootRan = true
            }

            var server: Server.Type?

            init() {
                server = TestServer.self
            }
        }

        let provider = TestProvider()
        let app = Application(providers: [
            provider
        ])

        XCTAssert(app.serverType == TestServer.self, "Provider did not provide TestServer")
        XCTAssert(provider.bootRan == true, "Application did not boot provider")
    }

    /**
        Tests that Providers override other
        init arguments to the application.
    */
    func testProvidersOverride() {
        final class TestServerAlpha: Server {
            init(host: String, port: Int, securityLayer: SecurityLayer) {}
            func start(responder: Responder, errors: ServerErrorHandler) throws {}
        }

        final class TestServerBeta: Server {
            init(host: String, port: Int, securityLayer: SecurityLayer) {}
            func start(responder: Responder, errors: ServerErrorHandler) throws {}
        }

        class TestProvider: Provider {
            func boot(with application: Application) {}

            var server: Server.Type?

            init() {
                server = TestServerAlpha.self
            }
        }

        let provider = TestProvider()

        let app = Application(serverType: TestServerBeta.self, providers: [
            provider
        ])

        XCTAssert(app.serverType == TestServerAlpha.self, "Provider did not override with TestServerAlpha")
    }

 }
