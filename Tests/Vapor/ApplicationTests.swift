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
            init() {}
            func start(host: String, port: Int, responder: Responder, errors: ServerErrorHandler) throws {}
        }

        class TestProvider: Provider {
            var bootRan = false

            func boot(with application: Application) {
                bootRan = true
            }

            var server: Server?

            init() {
                server = TestServer()
            }
        }

        let provider = TestProvider()
        let app = Application(providers: [
            provider
        ])

        XCTAssert(app.server.dynamicType == TestServer.self, "Provider did not provide TestServer")
        XCTAssert(provider.bootRan == true, "Application did not boot provider")
    }

    /**
        Tests that Providers override other
        init arguments to the application.
    */
    func testProvidersOverride() {
        final class TestServerAlpha: Server {
            init() {}
            func start(host: String, port: Int, responder: Responder, errors: ServerErrorHandler) throws {}
        }

        final class TestServerBeta: Server {
            init() {}
            func start(host: String, port: Int, responder: Responder, errors: ServerErrorHandler) throws {}
        }

        class TestProvider: Provider {
            func boot(with application: Application) {}

            var server: Server?

            init() {
                server = TestServerAlpha()
            }
        }

        let provider = TestProvider()

        let app = Application(server: TestServerBeta(), providers: [
            provider
        ])

        XCTAssert(app.server.dynamicType == TestServerAlpha.self, "Provider did not override with TestServerAlpha")
    }

 }
