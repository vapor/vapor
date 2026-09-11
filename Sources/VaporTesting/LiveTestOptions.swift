public import AsyncHTTPClient
public import NIOSSL

/// How a ``Vapor/Application/Method/running`` test runs: where the server binds, and how the client
/// that talks to it is set up.
public struct LiveTestOptions: Sendable {
    public var hostname: String
    public var port: Int
    public var clientOptions: LiveClientOptions

    public init(hostname: String = "127.0.0.1", port: Int = 0, clientOptions: LiveClientOptions = .init()) {
        self.hostname = hostname
        self.port = port
        self.clientOptions = clientOptions
    }

    public static var live: Self { .init() }
    public static func live(hostname: String = "127.0.0.1", port: Int = 0,
                            clientOptions: LiveClientOptions = .init()) -> Self {
        self.init(hostname: hostname, port: port, clientOptions: clientOptions)
    }
}

/// How the live test client talks to the running server.
///
/// With neither ``tls`` nor ``configuration`` set, requests go through `HTTPClient.shared`. Setting
/// either gives the test its own `HTTPClient`, which is shut down when the test scope ends.
///
/// These only affect a live test. In memory there is no connection to configure.
public struct LiveClientOptions: Sendable {
    /// Trust roots and client certificate for talking to a TLS-configured server. Takes precedence
    /// over ``configuration``'s `tlsConfiguration` when both are set.
    public var tls: TLSConfiguration?
    /// Full AsyncHTTPClient configuration, for anything ``tls`` doesn't cover. Defaults to the
    /// configuration `HTTPClient.shared` uses, so setting only ``tls`` changes only TLS.
    public var configuration: HTTPClient.Configuration?
    /// The longest any request may take. A request asking for less, through `beforeSend`, gets less.
    public var timeout: Duration

    public init(tls: TLSConfiguration? = nil, configuration: HTTPClient.Configuration? = nil, timeout: Duration = .seconds(30)) {
        self.tls = tls
        self.configuration = configuration
        self.timeout = timeout
    }

    /// The configuration for a dedicated `HTTPClient`, or `nil` when `HTTPClient.shared` will do.
    var httpClientConfiguration: HTTPClient.Configuration? {
        guard self.tls != nil || self.configuration != nil else { return nil }
        var configuration = self.configuration ?? .singletonConfiguration
        if let tls = self.tls {
            configuration.tlsConfiguration = tls
        }
        return configuration
    }
}
