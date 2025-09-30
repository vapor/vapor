import HTTPServerNew
import NIOHTTPTypes
import HTTPTypes
import NIOCore
import NIOConcurrencyHelpers

extension Application.Servers.Provider {
    public static var httpNew: Self {
        .init {
            $0.servers.use { $0.http.serverNew.shared }
        }
    }
}

extension Application.HTTP {
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
                        byteBufferAllocator: application.byteBufferAllocator
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
}
