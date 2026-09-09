import Configuration
import Logging

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

        /// Initialize the address config from a Swift Configuration `ConfigReader`.
        ///
        /// - Parameter config: The `ConfigReader` to read from.
        ///
        /// ## Configuration keys:
        /// - `hostname`: (string, optional): The hostname the server will run on.
        /// - `port`: (int, optional): The port the server will run on.
        /// - `bind`: (string, optional): The hostname and port together in the format `"hostname:port"`.
        /// - `unix-socket`: (string, optional): The path for the unix domain socket file the server will bind to.
        init(from config: ConfigReader) {
            self.hostname = config.string(forKey: "hostname")
            self.port = config.int(forKey: "port")
            self.bind = config.string(forKey: "bind")
            self.socketPath = config.string(forKey: "unix-socket")
        }
    }

    /// Errors that may be thrown when serving a server
    @nonexhaustive
    public enum AddressConfigurationError: Swift.Error {
        /// Incompatible flags were used together (for instance, specifying a socket path along with a port)
        case incompatibleFlags
    }

    /// Apply address configuration from CLI/environment to the server configuration.
    /// This only mutates `serverConfiguration.address` — it does not start the server.
    func applyAddressConfiguration(_ config: AddressConfiguration) {
        switch (config.hostname, config.port, config.bind, config.socketPath) {
        case (.none, .none, .none, .none):
            break // use defaults
        case (.none, .none, .none, .some(let socketPath)):
            self.serverConfiguration.address = .unixDomainSocket(path: socketPath)
        case (.none, .none, .some(let address), .none):
            let hostname = address.split(separator: ":").first.flatMap(String.init)
            let port = address.split(separator: ":").last.flatMap(String.init).flatMap(Int.init)
            if let hostname, let port {
                self.serverConfiguration.address = .hostname(hostname, port: port)
            } else {
                Logger.current.warning(
                    "Ignoring malformed bind address, expected \"hostname:port\".",
                    metadata: ["bind": "\(address)"]
                )
            }
        case (let hostname, let port, .none, .none):
            // Hostname and port are independent: either may be given on its own, and each replaces
            // only its own half of the address already configured. Matching on both being present
            // meant a lone `--port` fell through to `default` and was silently discarded.
            if let hostname {
                self.serverConfiguration.hostname = hostname
            }
            if let port {
                self.serverConfiguration.port = port
            }
        default:
            // A combination that cannot be honoured at once, such as `--bind` alongside `--port`,
            // or a socket path alongside either. Previously dropped without a word.
            Logger.current.warning(
                "Ignoring incompatible address options. Use --bind, or --unix-socket, or --hostname/--port."
            )
        }
    }
}
