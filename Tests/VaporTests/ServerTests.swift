import Vapor
import XCTest
import protocol AsyncHTTPClient.HTTPClientResponseDelegate
import Baggage

final class ServerTests: XCTestCase {
    func testPortOverride() throws {
        let env = Environment(
            name: "testing",
            arguments: ["vapor", "serve", "--port", "8123"]
        )

        let app = Application(env)
        defer { app.shutdown() }

        app.get("foo") { req in
            return "bar"
        }
        try app.start()
        let context = DefaultLoggingContext.topLevel(logger: app.logger)

        let res = try app.client.get("http://127.0.0.1:8123/foo", context: context).wait()
        XCTAssertEqual(res.body?.string, "bar")
    }
    
    func testSocketPathOverride() throws {
        let socketPath = "/tmp/\(UUID().uuidString).vapor.socket"

        let env = Environment(
            name: "testing",
            arguments: ["vapor", "serve", "--unix-socket", socketPath]
        )

        let app = Application(env)
        defer { app.shutdown() }

        app.get("foo") { req in
            return "bar"
        }
        try app.start()
        let context = DefaultLoggingContext.topLevel(logger: app.logger)

        let res = try app.client.get(.init(scheme: .httpUnixDomainSocket, host: socketPath, path: "/foo"), context: context).wait()
        XCTAssertEqual(res.body?.string, "bar")

        // no server should be bound to the port despite one being set on the configuration.
        XCTAssertThrowsError(try app.client.get("http://127.0.0.1:8080/foo", context: context).wait())
    }
    
    func testIncompatibleStartupOptions() throws {
        func checkForError(_ app: Application) {
            XCTAssertThrowsError(try app.start()) { error in
                XCTAssertNotNil(error as? ServeCommand.Error)
                guard let serveError = error as? ServeCommand.Error else {
                    XCTFail("\(error) is not a ServeCommandError")
                    return
                }
                
                XCTAssertEqual(ServeCommand.Error.incompatibleFlags, serveError)
            }
            app.shutdown()
        }
        
        var app = Application(Environment(
            name: "testing",
            arguments: ["vapor", "serve", "--port", "8123", "--unix-socket", "/path/to/socket"]
        ))
        checkForError(app)
        
        app = Application(Environment(
            name: "testing",
            arguments: ["vapor", "serve", "--hostname", "localhost", "--unix-socket", "/path/to/socket"]
        ))
        checkForError(app)
        
        app = Application(Environment(
            name: "testing",
            arguments: ["vapor", "serve", "--bind", "localhost:8123", "--unix-socket", "/path/to/socket"]
        ))
        checkForError(app)
        
        app = Application(Environment(
            name: "testing",
            arguments: ["vapor", "serve", "--bind", "localhost:8123", "--hostname", "1.2.3.4"]
        ))
        checkForError(app)
        
        app = Application(Environment(
            name: "testing",
            arguments: ["vapor", "serve", "--bind", "localhost:8123", "--port", "8081"]
        ))
        checkForError(app)
        
        app = Application(Environment(
            name: "testing",
            arguments: ["vapor", "serve", "--bind", "localhost:8123", "--port", "8081", "--unix-socket", "/path/to/socket"]
        ))
        checkForError(app)
        
        app = Application(Environment(
            name: "testing",
            arguments: ["vapor", "serve", "--bind", "localhost:8123", "--hostname", "1.2.3.4", "--unix-socket", "/path/to/socket"]
        ))
        checkForError(app)
        
        app = Application(Environment(
            name: "testing",
            arguments: ["vapor", "serve", "--hostname", "1.2.3.4", "--port", "8081", "--unix-socket", "/path/to/socket"]
        ))
        checkForError(app)
        
        app = Application(Environment(
            name: "testing",
            arguments: ["vapor", "serve", "--bind", "localhost:8123", "--hostname", "1.2.3.4", "--port", "8081", "--unix-socket", "/path/to/socket"]
        ))
        checkForError(app)
    }
    
    @available(*, deprecated)
    func testDeprecatedServerStartMethods() throws {
        /// TODO: This test may be removed in the next major version
        class OldServer: Server {
            var onShutdown: EventLoopFuture<Void> {
                preconditionFailure("We should never get here.")
            }
            func shutdown() { }
            
            var hostname:String? = ""
            var port:Int? = 0
            // only implements the old requirement
            func start(hostname: String?, port: Int?) throws {
                self.hostname = hostname
                self.port = port
            }
        }
        
        // Ensure we always start with something other than what we expect when calling start
        var oldServer = OldServer()
        XCTAssertNotNil(oldServer.hostname)
        XCTAssertNotNil(oldServer.port)
        
        // start() should set the hostname and port to nil
        oldServer = OldServer()
        try oldServer.start()
        XCTAssertNil(oldServer.hostname)
        XCTAssertNil(oldServer.port)
        
        // start(hostname: ..., port: ...) should set the hostname and port appropriately
        oldServer = OldServer()
        try oldServer.start(hostname: "1.2.3.4", port: 123)
        XCTAssertEqual(oldServer.hostname, "1.2.3.4")
        XCTAssertEqual(oldServer.port, 123)
        
        // start(address: .hostname(..., port: ...)) should set the hostname and port appropriately
        oldServer = OldServer()
        try oldServer.start(address: .hostname("localhost", port: 8080))
        XCTAssertEqual(oldServer.hostname, "localhost")
        XCTAssertEqual(oldServer.port, 8080)
        
        // start(address: .unixDomainSocket(path: ...)) should throw
        oldServer = OldServer()
        XCTAssertThrowsError(try oldServer.start(address: .unixDomainSocket(path: "/path")))
        
        class NewServer: Server {
            var onShutdown: EventLoopFuture<Void> {
                preconditionFailure("We should never get here.")
            }
            func shutdown() { }
            
            var hostname: String? = ""
            var port: Int? = 0
            var socketPath: String? = ""
            
            func start(address: BindAddress?) throws {
                switch address {
                case .none:
                    self.hostname = nil
                    self.port = nil
                    self.socketPath = nil
                case .hostname(let hostname, let port):
                    self.hostname = hostname
                    self.port = port
                    self.socketPath = nil
                case .unixDomainSocket(let path):
                    self.hostname = nil
                    self.port = nil
                    self.socketPath = path
                }
            }
        }
        
        // Ensure we always start with something other than what we expect when calling start
        var newServer = NewServer()
        XCTAssertNotNil(newServer.hostname)
        XCTAssertNotNil(newServer.port)
        XCTAssertNotNil(newServer.socketPath)

        // start() should set the hostname and port to nil
        newServer = NewServer()
        try newServer.start()
        XCTAssertNil(newServer.hostname)
        XCTAssertNil(newServer.port)
        XCTAssertNil(newServer.socketPath)

        // start(hostname: ..., port: ...) should set the hostname and port appropriately
        newServer = NewServer()
        try newServer.start(hostname: "1.2.3.4", port: 123)
        XCTAssertEqual(newServer.hostname, "1.2.3.4")
        XCTAssertEqual(newServer.port, 123)
        XCTAssertNil(newServer.socketPath)

        // start(address: .hostname(..., port: ...)) should set the hostname and port appropriately
        newServer = NewServer()
        try newServer.start(address: .hostname("localhost", port: 8080))
        XCTAssertEqual(newServer.hostname, "localhost")
        XCTAssertEqual(newServer.port, 8080)
        XCTAssertNil(newServer.socketPath)

        // start(address: .unixDomainSocket(path: ...)) should throw
        newServer = NewServer()
        try newServer.start(address: .unixDomainSocket(path: "/path"))
        XCTAssertNil(newServer.hostname)
        XCTAssertNil(newServer.port)
        XCTAssertEqual(newServer.socketPath, "/path")
        
    }

    func testConfigureHTTPDecompressionLimit() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        let context = DefaultLoggingContext.topLevel(logger: app.logger)

        let smallOrigString = "Hello, world!"
        let smallBody = ByteBuffer(base64String: "H4sIAAAAAAAAE/NIzcnJ11Eozy/KSVEEAObG5usNAAA=")! // "Hello, world!"
        let bigBody = ByteBuffer(base64String: "H4sIAAAAAAAAE/NIzcnJ11HILU3OgBBJmenpqUUK5flFOSkKJRmJeQpJqWn5RamKAICcGhUqAAAA")! // "Hello, much much bigger world than before!"

        // Max out at the smaller payload (.size is of compressed data)
        app.http.server.configuration.requestDecompression = .enabled(
            limit: .size(smallBody.readableBytes)
        )
        app.post("gzip") { $0.body.string ?? "" }

        try app.server.start()
        defer { app.server.shutdown() }

        // Small payload should just barely get through.
        let res = try app.client.post("http://localhost:8080/gzip", context: context) { req in
            req.headers.replaceOrAdd(name: .contentEncoding, value: "gzip")
            req.body = smallBody
        }.wait()
        XCTAssertEqual(res.body?.string, smallOrigString)

        // Big payload should be hard-rejected. We can't test for the raw NIOHTTPDecompression.DecompressionError.limit error here because
        // protocol decoding errors are only ever logged and can't be directly caught.
        do {
            _ = try app.client.post("http://localhost:8080/gzip", context: context) { req in
                req.headers.replaceOrAdd(name: .contentEncoding, value: "gzip")
                req.body = bigBody
            }.wait()
        } catch let error as HTTPClientError {
            XCTAssertEqual(error, HTTPClientError.remoteConnectionClosed)
        } catch {
            XCTFail("\(error)")
        }
    }

    func testLiveServer() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        app.routes.get("ping") { req -> String in
            return "123"
        }

        try app.testable().test(.GET, "/ping") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "123")
        }
    }

    func testCustomServer() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        app.servers.use(.custom)
        XCTAssertEqual(app.customServer.didStart, false)
        XCTAssertEqual(app.customServer.didShutdown, false)

        try app.server.start()
        XCTAssertEqual(app.customServer.didStart, true)
        XCTAssertEqual(app.customServer.didShutdown, false)

        app.server.shutdown()
        XCTAssertEqual(app.customServer.didStart, true)
        XCTAssertEqual(app.customServer.didShutdown, true)
    }

    func testMultipleChunkBody() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        let payload = [UInt8].random(count: 1 << 20)

        app.on(.POST, "payload", body: .collect(maxSize: "1gb")) { req -> HTTPStatus in
            guard let data = req.body.data else {
                throw Abort(.internalServerError)
            }
            XCTAssertEqual(payload.count, data.readableBytes)
            XCTAssertEqual([UInt8](data.readableBytesView), payload)
            return .ok
        }

        var buffer = ByteBufferAllocator().buffer(capacity: payload.count)
        buffer.writeBytes(payload)
        try app.testable(method: .running).test(.POST, "payload", body: buffer) { res in
            XCTAssertEqual(res.status, .ok)
        }
    }

    func testCollectedResponseBodyEnd() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        app.post("drain") { req -> EventLoopFuture<HTTPStatus> in
            let promise = req.eventLoop.makePromise(of: HTTPStatus.self)
            req.body.drain { result in
                switch result {
                case .buffer: break
                case .error(let error):
                    promise.fail(error)
                case .end:
                    promise.succeed(.ok)
                }
                return req.eventLoop.makeSucceededFuture(())
            }
            return promise.futureResult
        }

        try app.testable(method: .running).test(.POST, "drain", beforeRequest: { req in
            try req.content.encode(["hello": "world"])
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
        })
    }

    // https://github.com/vapor/vapor/issues/1786
    func testMissingBody() throws {
        struct User: Content { }

        let app = Application(.testing)
        defer { app.shutdown() }

        app.get("user") { req -> User in
            return try req.content.decode(User.self)
        }

        try app.testable().test(.GET, "/user") { res in
            XCTAssertEqual(res.status, .unsupportedMediaType)
        }
    }

    // https://github.com/vapor/vapor/issues/2245
    func testTooLargePort() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        app.http.server.configuration.port = .max
        XCTAssertThrowsError(try app.start())
    }

    func testEarlyExitStreamingRequest() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        app.on(.POST, "upload", body: .stream) { req -> EventLoopFuture<Int> in
            guard req.headers.first(name: "test") != nil else {
                return req.eventLoop.makeFailedFuture(Abort(.badRequest))
            }

            var count = 0
            let promise = req.eventLoop.makePromise(of: Int.self)
            req.body.drain { part in
                switch part {
                case .buffer(let buffer):
                    count += buffer.readableBytes
                case .error(let error):
                    promise.fail(error)
                case .end:
                    promise.succeed(count)
                }
                return req.eventLoop.makeSucceededFuture(())
            }
            return promise.futureResult
        }

        var buffer = ByteBufferAllocator().buffer(capacity: 10_000_000)
        buffer.writeString(String(repeating: "a", count: 10_000_000))

        try app.testable(method: .running).test(.POST, "upload", beforeRequest: { req in
            req.body = buffer
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .badRequest)
        }).test(.POST, "upload", beforeRequest: { req in
            req.body = buffer
            req.headers.replaceOrAdd(name: "test", value: "a")
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
        })
    }

    func testEchoServer() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        final class Context {
            var server: [String]
            var client: [String]
            init() {
                self.server = []
                self.client = []
            }
        }
        let context = Context()

        app.on(.POST, "echo", body: .stream) { request -> Response in
            Response(body: .init(stream: { writer in
                request.body.drain { body in
                    switch body {
                    case .buffer(let buffer):
                        context.server.append(buffer.string)
                        return writer.write(.buffer(buffer))
                    case .error(let error):
                        return writer.write(.error(error))
                    case .end:
                        return writer.write(.end)
                    }
                }
            }))
        }

        let port = 1337
        app.http.server.configuration.port = port
        app.environment.arguments = ["serve"]
        try app.start()

        let request = try HTTPClient.Request(
            url: "http://localhost:\(port)/echo",
            method: .POST,
            headers: [
                "transfer-encoding": "chunked"
            ],
            body: .stream(length: nil, { stream in
                stream.write(.byteBuffer(.init(string: "foo"))).flatMap {
                    stream.write(.byteBuffer(.init(string: "bar")))
                }.flatMap {
                    stream.write(.byteBuffer(.init(string: "baz")))
                }
            })
        )

        final class ResponseDelegate: HTTPClientResponseDelegate {
            typealias Response = HTTPClient.Response

            let context: Context
            init(context: Context) {
                self.context = context
            }

            func didReceiveBodyPart(
                task: HTTPClient.Task<HTTPClient.Response>,
                _ buffer: ByteBuffer
            ) -> EventLoopFuture<Void> {
                self.context.client.append(buffer.string)
                return task.eventLoop.makeSucceededFuture(())
            }

            func didFinishRequest(task: HTTPClient.Task<HTTPClient.Response>) throws -> HTTPClient.Response {
                .init(host: "", status: .ok, version: .init(major: 1, minor: 1), headers: [:], body: nil)
            }
        }
        let response = ResponseDelegate(context: context)
        _ = try app.http.client.shared.execute(
            request: request,
            delegate: response
        ).wait()
        
        XCTAssertEqual(context.server, ["foo", "bar", "baz"])
        XCTAssertEqual(context.client, ["foo", "bar", "baz"])
    }

    func testSkipStreaming() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        app.on(.POST, "echo", body: .stream) { request in
            "hello, world"
        }

        let port = 1337
        app.http.server.configuration.port = port
        app.environment.arguments = ["serve"]
        try app.start()

        let request = try HTTPClient.Request(
            url: "http://localhost:\(port)/echo",
            method: .POST,
            headers: [
                "transfer-encoding": "chunked"
            ],
            body: .stream(length: nil, { stream in
                stream.write(.byteBuffer(.init(string: "foo"))).flatMap {
                    stream.write(.byteBuffer(.init(string: "bar")))
                }.flatMap {
                    stream.write(.byteBuffer(.init(string: "baz")))
                }
            })
        )

        let a = try app.http.client.shared.execute(request: request).wait()
        XCTAssertEqual(a.status, .ok)
        let b = try app.http.client.shared.execute(request: request).wait()
        XCTAssertEqual(b.status, .ok)
    }

    func testStartWithValidSocketFile() throws {
        let socketPath = "/tmp/\(UUID().uuidString).vapor.socket"

        let app = Application(.testing)
        app.http.server.configuration.address = .unixDomainSocket(path: socketPath)
        defer {
            app.shutdown()
        }
        app.environment.arguments = ["serve"]
        XCTAssertNoThrow(try app.start())
    }

    func testStartWithUnsupportedSocketFile() throws {
        let app = Application(.testing)
        app.http.server.configuration.address = .unixDomainSocket(path: "/tmp")
        defer { app.shutdown() }

        XCTAssertThrowsError(try app.start())
    }

    func testStartWithInvalidSocketFilePath() throws {
        let app = Application(.testing)
        app.http.server.configuration.address = .unixDomainSocket(path: "/tmp/nonexistent/vapor.socket")
        defer { app.shutdown() }

        XCTAssertThrowsError(try app.start())
    }

    func testStartWithDefaultHostnameConfiguration() throws {
        let app = Application(.testing)
        app.http.server.configuration.address = .hostname(nil, port: nil)
        defer { app.shutdown() }
        app.environment.arguments = ["serve"]

        XCTAssertNoThrow(try app.start())
    }

    func testStartWithDefaultHostname() throws {
        let app = Application(.testing)
        app.http.server.configuration.address = .hostname(nil, port: 8008)
        defer { app.shutdown() }
        app.environment.arguments = ["serve"]

        XCTAssertNoThrow(try app.start())
    }

    func testStartWithDefaultPort() throws {
        let app = Application(.testing)
        app.http.server.configuration.address = .hostname("0.0.0.0", port: nil)
        defer { app.shutdown() }
        app.environment.arguments = ["serve"]
        
        XCTAssertNoThrow(try app.start())
    }
    
    func testAddressConfigurations() throws {
        var configuration = HTTPServer.Configuration()
        XCTAssertEqual(configuration.address, .hostname(HTTPServer.Configuration.defaultHostname, port: HTTPServer.Configuration.defaultPort))
        
        configuration = HTTPServer.Configuration(hostname: "1.2.3.4", port: 123)
        XCTAssertEqual(configuration.address, .hostname("1.2.3.4", port: 123))
        XCTAssertEqual(configuration.hostname, "1.2.3.4")
        XCTAssertEqual(configuration.port, 123)
        
        configuration = HTTPServer.Configuration(address: .hostname("1.2.3.4", port: 123))
        XCTAssertEqual(configuration.address, .hostname("1.2.3.4", port: 123))
        XCTAssertEqual(configuration.hostname, "1.2.3.4")
        XCTAssertEqual(configuration.port, 123)
        
        configuration = HTTPServer.Configuration(address: .hostname("1.2.3.4", port: nil))
        XCTAssertEqual(configuration.address, .hostname("1.2.3.4", port: nil))
        XCTAssertEqual(configuration.hostname, "1.2.3.4")
        XCTAssertEqual(configuration.port, HTTPServer.Configuration.defaultPort)
        
        configuration = HTTPServer.Configuration(address: .hostname(nil, port: 123))
        XCTAssertEqual(configuration.address, .hostname(nil, port: 123))
        XCTAssertEqual(configuration.hostname, HTTPServer.Configuration.defaultHostname)
        XCTAssertEqual(configuration.port, 123)
        
        configuration = HTTPServer.Configuration(address: .hostname(nil, port: nil))
        XCTAssertEqual(configuration.address, .hostname(nil, port: nil))
        XCTAssertEqual(configuration.hostname, HTTPServer.Configuration.defaultHostname)
        XCTAssertEqual(configuration.port, HTTPServer.Configuration.defaultPort)
        
        configuration = HTTPServer.Configuration(address: .unixDomainSocket(path: "/path"))
        XCTAssertEqual(configuration.address, .unixDomainSocket(path: "/path"))
        
        
        // Test mutating a config that was originally a socket path
        configuration = HTTPServer.Configuration(address: .unixDomainSocket(path: "/path"))
        XCTAssertEqual(configuration.address, .unixDomainSocket(path: "/path"))
        
        configuration.hostname = "1.2.3.4"
        XCTAssertEqual(configuration.hostname, "1.2.3.4")
        XCTAssertEqual(configuration.port, HTTPServer.Configuration.defaultPort)
        XCTAssertEqual(configuration.address, .hostname("1.2.3.4", port: nil))
        
        configuration.address = .unixDomainSocket(path: "/path")
        XCTAssertEqual(configuration.hostname, HTTPServer.Configuration.defaultHostname)
        XCTAssertEqual(configuration.port, HTTPServer.Configuration.defaultPort)
        XCTAssertEqual(configuration.address, .unixDomainSocket(path: "/path"))
        
        configuration.port = 123
        XCTAssertEqual(configuration.hostname, HTTPServer.Configuration.defaultHostname)
        XCTAssertEqual(configuration.port, 123)
        XCTAssertEqual(configuration.address, .hostname(nil, port: 123))
        
        configuration.hostname = "1.2.3.4"
        XCTAssertEqual(configuration.hostname, "1.2.3.4")
        XCTAssertEqual(configuration.port, 123)
        XCTAssertEqual(configuration.address, .hostname("1.2.3.4", port: 123))
        
        configuration.address = .hostname(nil, port: nil)
        XCTAssertEqual(configuration.hostname, HTTPServer.Configuration.defaultHostname)
        XCTAssertEqual(configuration.port, HTTPServer.Configuration.defaultPort)
        XCTAssertEqual(configuration.address, .hostname(nil, port: nil))
    }

    func testQuiesceKeepAliveConnections() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        app.get("hello") { req in
            "world"
        }

        let port = 1337
        app.http.server.configuration.port = port
        app.environment.arguments = ["serve"]
        try app.start()

        let request = try HTTPClient.Request(
            url: "http://localhost:\(port)/hello",
            method: .GET,
            headers: ["connection": "keep-alive"]
        )
        let a = try app.http.client.shared.execute(request: request).wait()
        XCTAssertEqual(a.headers.connection, .keepAlive)
    }

    override class func setUp() {
        XCTAssertTrue(isLoggingConfigured)
    }
}

extension Application.Servers.Provider {
    static var custom: Self {
        .init {
            $0.servers.use { $0.customServer }
        }
    }
}

extension Application {
    struct Key: StorageKey {
        typealias Value = CustomServer
    }

    var customServer: CustomServer {
        if let existing = self.storage[Key.self] {
            return existing
        } else {
            let new = CustomServer()
            self.storage[Key.self] = new
            return new
        }
    }
}

final class CustomServer: Server {
    var didStart: Bool
    var didShutdown: Bool
    var onShutdown: EventLoopFuture<Void> {
        fatalError()
    }

    init() {
        self.didStart = false
        self.didShutdown = false
    }
    
    func start(hostname: String?, port: Int?) throws {
        try self.start(address: .hostname(hostname, port: port))
    }
    
    func start(address: BindAddress?) throws {
        self.didStart = true
    }

    func shutdown() {
        self.didShutdown = true
    }
}

private extension ByteBuffer {
    init?(base64String: String) {
        guard let decoded = Data(base64Encoded: base64String) else { return nil }
        var buffer = ByteBufferAllocator().buffer(capacity: decoded.count)
        buffer.writeBytes(decoded)
        self = buffer
    }
}
