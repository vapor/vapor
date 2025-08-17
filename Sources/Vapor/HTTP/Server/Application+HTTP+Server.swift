import HTTPServerNew
import NIOHTTPTypes
import HTTPTypes
import NIOCore
import NIOConcurrencyHelpers

extension Application.Servers.Provider {
    public static var http: Self {
        .init {
            $0.servers.use { $0.http.server.shared }
        }
    }

    public static var httpNew: Self {
        .init {
            $0.servers.use { $0.http.serverNew.shared }
        }
    }
}

extension Application.HTTP {
    public var server: Server {
        .init(application: self.application)
    }

    public var serverNew: ServerNew {
        .init(application: self.application)
    }

    public struct ServerNew: Sendable {
        let application: Application

        public var shared: HTTPServer<HTTP1Channel> {
            if let existing = self.application.storage[Key.self] {
                return existing
            } else {
                let bindAddress: HTTPServerNew.BindAddress
                if case let .hostname(ip, port) = self.application.serverConfiguration.address {
                    bindAddress = .hostname(ip, port: port)
                } else if case let .unixDomainSocket(path) = self.application.serverConfiguration.address {
                    bindAddress = .unixDomainSocket(path: path)
                } else {
                    bindAddress = .hostname()
                }
                let config = HTTPServerNew.ServerConfiguration(address: bindAddress)
                let responder: any Responder
                switch self.application.responder {
                case .default:
                    responder = DefaultResponder(routes: self.application.routes, middleware: self.application.middleware.resolve(), reportMetrics: self.application.serverConfiguration.reportMetrics)
                case .provided(let provided):
                    responder = provided
                }
                let new: HTTPServer<HTTP1Channel> = try! HTTPServerBuilder.http1().buildServer(configuration: config, eventLoopGroup: self.application.eventLoopGroup, logger: self.application.logger, responder: { req, responseWriter, channel  in
                    application.logger.info("Request received with new Vapor 5 server")

                    let vaporRequest = Vapor.Request(
                        application: self.application,
                        method: req.method,
                        url: .init(scheme: .init(req.uri.scheme?.rawValue), host: req.uri.host, port: req.uri.port, path: req.uri.path, query: req.uri.query),
                        version: .init(major: 1, minor: 1),
                        headersNoUpdate: .init(req.headers),
                        remoteAddress: channel.remoteAddress,
                        logger: self.application.logger,
                        byteBufferAllocator: application.byteBufferAllocator,
                        on: application.eventLoopGroup.any()
                    )
                    vaporRequest.newBodyStorage.withLockedValue { $0 = req.body }

                    let vaporResponse = try await responder.respond(to: vaporRequest)
                    let httpResponse = HTTPResponse(status: vaporResponse.status, headerFields: vaporResponse.headers)

                    var bodyWriter: any ResponseBodyWriter = try await responseWriter.writeHead(httpResponse)
                    try await vaporResponse.body.write(&bodyWriter)
                    application.logger.info("Response sent with new Vapor 5 server")

                }, onServerRunning: { channel in
                    await self.application.serverConfiguration.onServerRunning(channel)
                    self.application.sharedNewAddress.withLockedValue { $0 = channel.localAddress }
                }) as! HTTPServer<HTTP1Channel>
                self.application.storage[Key.self] = new
                return new
            }
        }

        struct Key: StorageKey, Sendable {
            typealias Value = HTTPServer<HTTP1Channel>
        }
    }

    public struct Server: Sendable {
        let application: Application

        public var shared: HTTPServerOld {
            if let existing = self.application.storage[Key.self] {
                return existing
            } else {
                let responder: any Responder
                switch self.application.responder {
                case .default:
                    responder = DefaultResponder(routes: self.application.routes, middleware: self.application.middleware.resolve(), reportMetrics: self.application.serverConfiguration.reportMetrics)
                case .provided(let provided):
                    responder = provided
                }
                let new = HTTPServerOld.init(
                    application: self.application,
                    responder: responder,
                    configuration: self.configuration,
                    on: self.application.eventLoopGroup
                )
                self.application.storage[Key.self] = new
                return new
            }
        }

        struct Key: StorageKey, Sendable {
            typealias Value = HTTPServerOld
        }

        /// The configuration for the HTTP server.
        ///
        /// Although the configuration can be changed after the server has started, a warning will be logged
        /// and the configuration will be discarded if an option will no longer be considered.
        /// 
        /// These include the following properties, which are only read once when the server starts:
        /// - ``HTTPServerOld/Configuration-swift.struct/address``
        /// - ``HTTPServerOld/Configuration-swift.struct/hostname``
        /// - ``HTTPServerOld/Configuration-swift.struct/port``
        /// - ``HTTPServerOld/Configuration-swift.struct/backlog``
        /// - ``HTTPServerOld/Configuration-swift.struct/reuseAddress``
        /// - ``HTTPServerOld/Configuration-swift.struct/tcpNoDelay``
        public var configuration: HTTPServerOld.Configuration {
            get {
                self.application.storage[ConfigurationKey.self] ?? .init(
                    logger: self.application.logger
                )
            }
            nonmutating set {
                /// If a server is available, configure it directly, otherwise cache a configuration instance
                /// here to be used until the server is instantiated.
                if let server = self.application.storage[Key.self] {
                    server.configuration = newValue
                } else {
                    self.application.storage[ConfigurationKey.self] = newValue
                }
            }
        }

        struct ConfigurationKey: StorageKey, Sendable {
            typealias Value = HTTPServerOld.Configuration
        }
    }
}
