@testable import Vapor
import Configuration
import Testing
import VaporTesting

/// Covers the command-line address flags, which reach the server via
/// `Application.applyAddressConfiguration(_:)` on the way through `run()` and `start()`.
///
/// The nested `Address Configuration Tests` suite in `ServerTests` covers the
/// `ServerConfiguration.hostname`/`port` accessors instead, by setting them in code — nothing there
/// goes through the flags, which is how a lone `--port` came to be silently discarded.
@Suite("Address Configuration Flags")
struct AddressConfigurationFlagTests {
    /// Runs `arguments` through the same `ConfigReader` path the entry points use.
    private func apply(_ arguments: [String], to app: Application) {
        let reader = ConfigReader(provider: CommandLineArgumentsProvider(arguments: ["vapor"] + arguments))
        app.applyAddressConfiguration(Application.AddressConfiguration(from: reader))
    }

    @Test("--port on its own overrides the port and keeps the hostname")
    func testPortAlone() async throws {
        try await withApp { app in
            app.serverConfiguration.address = .hostname("192.0.2.1", port: 8080)
            self.apply(["--port", "8099"], to: app)
            #expect(app.serverConfiguration.address == .hostname("192.0.2.1", port: 8099))
        }
    }

    @Test("--hostname on its own overrides the hostname and keeps the port")
    func testHostnameAlone() async throws {
        try await withApp { app in
            app.serverConfiguration.address = .hostname("192.0.2.1", port: 8080)
            self.apply(["--hostname", "0.0.0.0"], to: app)
            #expect(app.serverConfiguration.address == .hostname("0.0.0.0", port: 8080))
        }
    }

    @Test("--hostname and --port together set both")
    func testHostnameAndPort() async throws {
        try await withApp { app in
            app.serverConfiguration.address = .hostname("192.0.2.1", port: 8080)
            self.apply(["--hostname", "0.0.0.0", "--port", "8099"], to: app)
            #expect(app.serverConfiguration.address == .hostname("0.0.0.0", port: 8099))
        }
    }

    @Test("--port replaces a socket path with a hostname address")
    func testPortOverridesSocketPath() async throws {
        try await withApp { app in
            app.serverConfiguration.address = .unixDomainSocket(path: "/tmp/vapor.sock")
            self.apply(["--port", "8099"], to: app)
            #expect(app.serverConfiguration.port == 8099)
            #expect(app.serverConfiguration.address != .unixDomainSocket(path: "/tmp/vapor.sock"))
        }
    }

    @Test("--bind sets hostname and port together")
    func testBind() async throws {
        try await withApp { app in
            app.serverConfiguration.address = .hostname("192.0.2.1", port: 8080)
            self.apply(["--bind", "0.0.0.0:8099"], to: app)
            #expect(app.serverConfiguration.address == .hostname("0.0.0.0", port: 8099))
        }
    }

    @Test("--unix-socket sets a socket path")
    func testUnixSocket() async throws {
        try await withApp { app in
            self.apply(["--unix-socket", "/tmp/vapor-test.sock"], to: app)
            #expect(app.serverConfiguration.address == .unixDomainSocket(path: "/tmp/vapor-test.sock"))
        }
    }

    @Test("No address flags leaves the configured address alone")
    func testNoFlags() async throws {
        try await withApp { app in
            app.serverConfiguration.address = .hostname("192.0.2.1", port: 8080)
            self.apply([], to: app)
            #expect(app.serverConfiguration.address == .hostname("192.0.2.1", port: 8080))
        }
    }

    @Test("Incompatible flags leave the configured address alone")
    func testIncompatibleFlagsAreIgnored() async throws {
        try await withApp { app in
            app.serverConfiguration.address = .hostname("192.0.2.1", port: 8080)
            self.apply(["--bind", "0.0.0.0:8099", "--port", "9000"], to: app)
            #expect(app.serverConfiguration.address == .hostname("192.0.2.1", port: 8080))
        }
    }
}
