import AsyncHTTPClient
import NIOSSL

public struct LiveTestOptions: Sendable {
    public var hostname = "127.0.0.1"
    public var port = 0
    public var clientOptions = LiveClientOptions()

    public static var live: Self { .init() }
    public static func live(hostname: String = "127.0.0.1", port: Int = 0,
                            clientOptions: LiveClientOptions = .init()) -> Self {
        self.init(hostname: hostname, port: port, clientOptions: clientOptions)
    }
}

public struct LiveClientOptions: Sendable {
    /// Trust roots / client cert for talking to a TLS-configured server. Nil = plaintext,
    /// or the system roots if the server has TLS on.
    var tls: TLSConfiguration?
    /// Full AsyncHTTPClient configuration for anything the above doesn't cover.
    var configuration: HTTPClient.Configuration?
    var timeout: Duration = .seconds(30)

    public init() {}
}
