import Core
import Dispatch
import HTTP
import TCP

public final class EngineClient: Client {
    /// See Client.makeConnectedClient
    public func makeConnectedClient(
        config: ConnectedClientConfig
    ) throws -> ConnectedClient {
        return EngineConnectedClient(config: config)
    }
}

/// A TCP based server with HTTP parsing and serialization pipeline.
public final class EngineConnectedClient: ConnectedClient {
    /// Chosen configuration for this server.
    public let config: ConnectedClientConfig

    /// Create a new EngineServer using config struct.
    public init(config: ConnectedClientConfig) {
        self.config = config
    }

    /// Start the server. Server protocol requirement.
    public func respond(to req: Request) throws -> Future<Response> {
        let promise = Promise(Response.self)

        // create a tcp client
        let socket = try TCP.Socket()
        try socket.connect(
            hostname: req.uri.hostname ?? "",
            port: req.uri.port ?? 80
        )
        let tcp = TCP.Client(
            socket: socket,
            queue: config.queue
        )
        let client = HTTP.Client(tcp: tcp)

        let emitter = RequestEmitter()
        let serializer = RequestSerializer()
        let parser = ResponseParser()

        emitter.stream(to: serializer)
            .stream(to: client)
            .stream(to: parser)
            .drain
        { response in
            promise.complete(response)
        }

        emitter.errorStream = { error in
            promise.fail(error)
        }

        client.tcp.start()

        // emite request
        req.headers[.host] = req.uri.hostname ?? ""
        req.headers[.userAgent] = "vapor/engine 3.0"

        emitter.emit(req)

        return promise.future
    }
}

// MARK: Utilities

fileprivate final class RequestEmitter: Core.OutputStream {
    typealias Output = Request
    var outputStream: OutputHandler?
    var errorStream: ErrorHandler?

    init() {}

    func emit(_ request: Request) {
        outputStream?(request)
    }
}
