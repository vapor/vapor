import XCTest
@testable import Vapor
import Engine

class DropletTests: XCTestCase {
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
        let drop = Droplet(workDir: workDir)

        let request = try Request(method: .get, uri: "/styles/app.css")

        guard let response = try? drop.respond(to: request) else {
            XCTFail("drop could not respond")
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
        on the Droplet and that the boot
        method is being called.
    */
    func testProviders() {
        final class TestServer: Server {
            var host: String
            var port: Int
            var securityLayer: SecurityLayer
            init(host: String, port: Int, securityLayer: SecurityLayer) throws {
                self.host = host
                self.port = port
                self.securityLayer = securityLayer
            }
            func start(responder: Responder, errors: ServerErrorHandler) throws {}
        }

        class TestProvider: Provider {
            var bootRan = false

            func boot(with droplet: Droplet) {
                bootRan = true
            }

            var server: Server.Type?

            init() {
                server = TestServer.self
            }
        }

        let provider = TestProvider()
        let drop = Droplet(providers: [
            provider
        ])

        XCTAssert(drop.server == TestServer.self, "Provider did not provide TestServer")
        XCTAssert(provider.bootRan == true, "Droplet did not boot provider")
    }

    /**
        Tests that Providers override other
        init arguments to the droplet.
    */
    func testProvidersOverride() {
        final class TestServerAlpha: Server {
            var host: String
            var port: Int
            var securityLayer: SecurityLayer
            init(host: String, port: Int, securityLayer: SecurityLayer) throws {
                self.host = host
                self.port = port
                self.securityLayer = securityLayer
            }
            func start(responder: Responder, errors: ServerErrorHandler) throws {}
        }

        final class TestServerBeta: Server {
            var host: String
            var port: Int
            var securityLayer: SecurityLayer
            init(host: String, port: Int, securityLayer: SecurityLayer) throws {
                self.host = host
                self.port = port
                self.securityLayer = securityLayer
            }
            func start(responder: Responder, errors: ServerErrorHandler) throws {}
        }

        class TestProvider: Provider {
            func boot(with droplet: Droplet) {}

            var server: Server.Type?

            init() {
                server = TestServerAlpha.self
            }
        }

        let provider = TestProvider()

        let drop = Droplet(server: TestServerBeta.self, providers: [
            provider
        ])

        XCTAssert(drop.server == TestServerAlpha.self, "Provider did not override with TestServerAlpha")
    }

 }
