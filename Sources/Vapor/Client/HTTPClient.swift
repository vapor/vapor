import NIO
import NIOSSL
import NIOHTTP1

public final class HTTPClient {
    public struct Request {
        public var method: HTTPMethod
        public var url: URL
        public var headers: HTTPHeaders
        public var body: ByteBuffer?
        
        public init(method: HTTPMethod = .GET, url: URL = .root, headers: HTTPHeaders = [:], body: ByteBuffer? = nil) {
            self.method = method
            self.url = url
            self.headers = headers
            self.body = body
        }
    }
    
    public struct Response {
        public var status: HTTPStatus
        public var headers: HTTPHeaders
        public var body: ByteBuffer?
        
        public init(status: HTTPStatus = .ok, headers: HTTPHeaders = [:], body: ByteBuffer? = nil) {
            self.status = status
            self.headers = headers
            self.body = body
        }
    }
    
    /// Configuration options for `HTTPClient`.
    public struct Configuration {
        public var tlsConfig: TLSConfiguration?
        
        /// The timeout that will apply to the connection attempt.
        public var connectTimeout: TimeAmount
        
        public var proxy: Proxy
        
        /// Optional closure, which fires when a networking error is caught.
        public var errorHandler: (Error) -> ()
        
        /// Creates a new `HTTPClientConfig`.
        ///
        public init(
            tlsConfig: TLSConfiguration? = nil,
            connectTimeout: TimeAmount = TimeAmount.seconds(10),
            proxy: Proxy = .none,
            errorHandler: @escaping (Error) -> () = { _ in }
        ) {
            self.tlsConfig = tlsConfig
            self.connectTimeout = connectTimeout
            self.proxy = proxy
            self.errorHandler = errorHandler
        }
    }
    
    public struct Proxy {
        enum Storage {
            case none
            case server(hostname: String, port: Int)
        }
        
        public static var none: Proxy {
            return .init(storage: .none)
        }
        
        public static func server(url: URLRepresentable) -> Proxy? {
            guard let url = url.convertToURL() else {
                return nil
            }
            guard let hostname = url.host else {
                return nil
            }
            return .server(hostname: hostname, port: url.port ?? 80)
        }
        
        public static func server(hostname: String, port: Int) -> Proxy {
            return .init(storage: .server(hostname: hostname, port: port))
        }
        
        var storage: Storage
    }

    
    public let configuration: Configuration
    
    public let eventLoopGroup: EventLoopGroup
    
    public init(configuration: Configuration = .init(), on eventLoopGroup: EventLoopGroup) {
        self.configuration = configuration
        self.eventLoopGroup = eventLoopGroup
    }
    
    public func send(_ request: HTTPClient.Request) -> EventLoopFuture<HTTPClient.Response> {
        let hostname = request.url.host ?? ""
        let port = request.url.port ?? (request.url.scheme == "https" ? 443 : 80)
        let tlsConfig: TLSConfiguration?
        switch request.url.scheme {
        case "https":
            tlsConfig = self.configuration.tlsConfig ?? .forClient()
        default:
            tlsConfig = nil
        }
        let eventLoop = self.eventLoopGroup.next()
        
        let bootstrap = ClientBootstrap(group: eventLoop)
            .connectTimeout(self.configuration.connectTimeout)
            .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .channelInitializer
        { channel in
            var handlers: [(String, ChannelHandler)] = []
            var httpHandlerNames: [String] = []
            
            switch self.configuration.proxy.storage {
            case .none:
                if let tlsConfig = tlsConfig {
                    let sslContext = try! NIOSSLContext(configuration: tlsConfig)
                    let tlsHandler = try! NIOSSLClientHandler(
                        context: sslContext,
                        serverHostname: hostname.isIPAddress() ? nil : hostname
                    )
                    handlers.append(("tls", tlsHandler))
                }
            case .server:
                // tls will be set up after connect
                break
            }
            
            let httpReqEncoder = HTTPRequestEncoder()
            handlers.append(("http-encoder", httpReqEncoder))
            httpHandlerNames.append("http-encoder")
            
            let httpResDecoder = ByteToMessageHandler(HTTPResponseDecoder())
            handlers.append(("http-decoder", httpResDecoder))
            httpHandlerNames.append("http-decoder")
            
            switch self.configuration.proxy.storage {
            case .none: break
            case .server:
                let proxy = HTTPClientProxyHandler(hostname: hostname, port: port) { context in
                    // re-add HTTPDecoder since it may consider the connection to be closed
                    _ = context.pipeline.removeHandler(name: "http-decoder")
                    _ = context.pipeline.addHandler(
                        ByteToMessageHandler(HTTPResponseDecoder()),
                        name: "http-decoder",
                        position: .after(httpReqEncoder)
                    )
                    
                    // if necessary, add TLS handlers
                    if let tlsConfig = tlsConfig {
                        let sslContext = try! NIOSSLContext(configuration: tlsConfig)
                        let tlsHandler = try! NIOSSLClientHandler(
                            context: sslContext,
                            serverHostname: hostname.isIPAddress() ? nil : hostname
                        )
                        _ = context.pipeline.addHandler(tlsHandler, position: .first)
                    }
                }
                handlers.append(("http-proxy", proxy))
            }
            
            let clientResDecoder = HTTPClientResponseDecoder()
            handlers.append(("client-decoder", clientResDecoder))
            httpHandlerNames.append("client-decoder")
            
            let clientReqEncoder = HTTPClientRequestEncoder(hostname: hostname)
            handlers.append(("client-encoder", clientReqEncoder))
            httpHandlerNames.append("client-encoder")
            
            let handler = HTTPClientHandler()
            httpHandlerNames.append("client")
            
            let upgrader = HTTPClientUpgradeHandler(httpHandlerNames: httpHandlerNames)
            handlers.append(("upgrader", upgrader))
            handlers.append(("client", handler))
            return .andAllSucceed(
                handlers.map { channel.pipeline.addHandler($1, name: $0, position: .last) },
                on: channel.eventLoop
            )
        }
        let connectHostname: String
        let connectPort: Int
        switch self.configuration.proxy.storage {
        case .none:
            connectHostname = hostname
            connectPort = port
        case .server(let hostname, let port):
            connectHostname = hostname
            connectPort = port
        }
        
        return bootstrap.connect(
            host: connectHostname,
            port: connectPort
        ).flatMap { channel in
            let promise = channel.eventLoop.makePromise(of: HTTPClient.Response.self)
            let context = HTTPClientRequestContext(request: request, promise: promise)
            channel.write(context, promise: nil)
            return promise.futureResult.flatMap { response in
                #warning("TODO: http client upgrade")
//                if request.upgrader != nil {
//                    // upgrader is responsible for closing
//                    return channel.eventLoop.makeSucceededFuture(response)
//                } else {
                    return channel.close().map { response }
//                }
            }
        }
    }
}
