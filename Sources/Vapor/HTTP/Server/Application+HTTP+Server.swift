import HTTPServerNew
import NIOHTTPTypes
import HTTPTypes

extension Application.Servers.Provider {
    public static var http: Self {
        .init {
            $0.servers.use { $0.http.server.shared }
        }
    }

    public static var httpNew: Self {
        .init {
            $0.servers.use { $0.http.server.sharedNew }
        }
    }
}

extension Application.HTTP {
    public var server: Server {
        .init(application: self.application)
    }
    
    public struct Server: Sendable {
        let application: Application

        public var sharedNew: HTTPServer<HTTP1Channel> {
            if let existing = self.application.storage[NewKey.self] {
                return existing
            } else {
                let new: HTTPServer<HTTP1Channel> = try! HTTPServerBuilder.http1().buildServer(configuration: .init(), eventLoopGroup: self.application.eventLoopGroup, logger: self.application.logger) { req, responseWriter, channel  in
                    application.logger.info("Request received with new Vapor 5 server")

                    let vaporRequest = Vapor.Request(
                        application: self.application,
                        method: req.method,
                        url: .init(path: req.uri.path),
                        version: .init(major: 1, minor: 1),
                        headersNoUpdate: .init(req.headers),
                        remoteAddress: nil,
                        logger: self.application.logger,
                        byteBufferAllocator: application.byteBufferAllocator,
                        on: application.eventLoopGroup.any()
                    )

                    let vaporResponse = try await application.responder.current.respond(to: vaporRequest).get()
                    let httpResponse = HTTPResponse(status: vaporResponse.status, headerFields: vaporResponse.headers)

                    var bodyWriter: any ResponseBodyWriter = try await responseWriter.writeHead(httpResponse)
                    try await vaporResponse.body.write(&bodyWriter)
                    application.logger.info("Response sent with new Vapor 5 server")

                } as! HTTPServer<HTTP1Channel>
                self.application.storage[NewKey.self] = new
                return new
            }
        }

        public var shared: HTTPServerOld {
            if let existing = self.application.storage[Key.self] {
                return existing
            } else {
                let new = HTTPServerOld.init(
                    application: self.application,
                    responder: self.application.responder.current,
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

        struct NewKey: StorageKey, Sendable {
            typealias Value = HTTPServer<HTTP1Channel>
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
