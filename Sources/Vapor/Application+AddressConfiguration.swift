import Foundation
import NIOConcurrencyHelpers
import NIOPosix
import NIOCore

extension Application {
    struct AddressConfiguration: Sendable {
        /// The hostname the server will run on.
        var hostname: String?

        /// The port the server will run on.
        var port: Int?

        /// Convenience for setting hostname and port together.
        var bind: String?

        /// The path for the unix domain socket file the server will bind to.
        var socketPath: String?
    }

    /// Errors that may be thrown when serving a server
    @nonexhaustive
    public enum AddressConfigurationError: Swift.Error {
        /// Incompatible flags were used together (for instance, specifying a socket path along with a port)
        case incompatibleFlags
    }
    
    struct SendableBox: Sendable {
        var didShutdown: Bool
        var running: Application.Running?
        var server: (any Server)?
    }

    func _startup(addressConfiguration: AddressConfiguration) async throws {
        switch (addressConfiguration.hostname, addressConfiguration.port, addressConfiguration.bind, addressConfiguration.socketPath) {
        case (.none, .none, .none, .none): // use defaults
            try await self.server.start()

        case (.none, .none, .none, .some(let socketPath)): // unix socket
            self.serverConfiguration.address = .unixDomainSocket(path: socketPath)
            try await self.server.start()
        case (.none, .none, .some(let address), .none): // bind ("hostname:port")
            let hostname = address.split(separator: ":").first.flatMap(String.init)
            let port = address.split(separator: ":").last.flatMap(String.init).flatMap(Int.init)
            self.serverConfiguration.address = .hostname(hostname!, port: port!)
            try await self.server.start()

        case (let hostname, let port, .none, .none): // hostname / port
            self.serverConfiguration.address = .hostname(hostname!, port: port!)
            try await self.server.start()
        default: throw AddressConfigurationError.incompatibleFlags
        }

        var box = self.box.withLockedValue { $0 }
        box.server = self.server

        // allow the server to be stopped or waited for
        let promise = MultiThreadedEventLoopGroup.singleton.any().makePromise(of: Void.self)
        self.running = .start(using: promise)
        box.running = self.running

        self.box.withLockedValue { $0 = box }
    }
    
    func _shutdown() async {
        var box = self.box.withLockedValue { $0 }
        box.didShutdown = true
        box.running?.stop()
        try? await box.server?.shutdown()
        self.box.withLockedValue { $0 = box }
    }
}
