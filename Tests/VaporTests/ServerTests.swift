import Vapor
import XCTest
import protocol AsyncHTTPClient.HTTPClientResponseDelegate
import NIO
import NIOConcurrencyHelpers
import NIOHTTP1
import NIOSSL
import Atomics
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
    
    func testHTTPLargeDecompression_2766() throws {
        let payload_2766 = "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"
        
        let jsonPayload = ByteBuffer(base64String: payload_2766)! // Payload from #2766

        let app = Application(.testing)
        defer { app.shutdown() }
        
        // Max out at the smaller payload (.size is of compressed data)
        app.http.server.configuration.requestDecompression = .enabled(limit: .size(200_000))
        app.post("gzip") { $0.body.string ?? "" }
        
        try app.server.start()
        defer { app.server.shutdown() }
        let context = DefaultLoggingContext.topLevel(logger: app.logger)
        
        // Small payload should just barely get through.
        let res = try app.client.post("http://localhost:8080/gzip", context: context) { req in
            req.headers.replaceOrAdd(name: .contentEncoding, value: "gzip")
            req.headers.replaceOrAdd(name: .contentType, value: "application/json")
            req.body = jsonPayload
        }.wait()
        
        if let body = res.body {
            // Validate that we received a valid JSON object
            struct Nothing: Codable {}
            XCTAssertNoThrow(try JSONDecoder().decode(Nothing.self, from: body))
        } else {
            XCTFail()
        }
    }

    func testConfigureHTTPDecompressionLimit() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        let context = DefaultLoggingContext.topLevel(logger: app.logger)

        let smallOrigString = "Hello, world!"
        let smallBody = ByteBuffer(base64String: "H4sIAAAAAAAAE/NIzcnJ11Eozy/KSVEEAObG5usNAAAA")! // "Hello, world!"
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

    func testRequestBodyStreamGetsFinalisedEvenIfClientDisappears() {
        let app = Application(.testing)
        app.http.server.configuration.hostname = "127.0.0.1"
        app.http.server.configuration.port = 0
        defer { app.shutdown() }

        let serverIsFinalisedPromise = app.eventLoopGroup.any().makePromise(of: Void.self)
        let allDonePromise = app.eventLoopGroup.any().makePromise(of: Void.self)

        app.on(.POST, "hello", body: .stream) { req -> Response in
            return Response(body: .init(stream: { writer in
                req.body.drain { stream in
                    switch stream {
                    case .buffer:
                        ()
                    case .end:
                        serverIsFinalisedPromise.succeed(())
                        writer.write(.end, promise: nil)
                    case .error(let error):
                        serverIsFinalisedPromise.fail(error)
                        writer.write(.error(error), promise: nil)
                    }
                    return allDonePromise.futureResult
                }
            }))
        }

        app.environment.arguments = ["serve"]
        XCTAssertNoThrow(try app.start())

        XCTAssertNotNil(app.http.server.shared.localAddress)
        guard let localAddress = app.http.server.shared.localAddress,
              let ip = localAddress.ipAddress,
              let port = localAddress.port else {
            XCTFail("couldn't get ip/port from \(app.http.server.shared.localAddress.debugDescription)")
            return
        }

        let tenMB = ByteBuffer(repeating: 0x41, count: 10 * 1024 * 1024)
        XCTAssertThrowsError(try app.http.client.shared.execute(.POST,
                                                                url: "http://\(ip):\(port)/hello",
                                                                body: .byteBuffer(tenMB),
                                                                deadline: .now() + .milliseconds(100)).wait()) { error in
            if let error = error as? HTTPClientError {
                #warning("Fix")
                XCTAssert(error == .readTimeout/* || error == .deadlineExceeded*/)
            } else {
                XCTFail("unexpected error: \(error)")
            }
        }

        allDonePromise.succeed(()) // This unblocks the server
        XCTAssertThrowsError(try serverIsFinalisedPromise.futureResult.wait()) { error in
            XCTAssertEqual(HTTPParserError.invalidEOFState, error as? HTTPParserError)
        }
    }

    func testRequestBodyBackpressureWorks() {
        let app = Application(.testing)
        app.http.server.configuration.hostname = "127.0.0.1"
        app.http.server.configuration.port = 0
        defer { app.shutdown() }

        let numberOfTimesTheServerGotOfferedBytes = ManagedAtomic<Int>(0)
        let bytesTheServerSaw = ManagedAtomic<Int>(0)
        let bytesTheClientSent = ManagedAtomic<Int>(0)
        let serverSawEnd = ManagedAtomic<Bool>(false)
        let serverSawRequest = ManagedAtomic<Bool>(false)
        let allDonePromise = app.eventLoopGroup.any().makePromise(of: Void.self)

        app.on(.POST, "hello", body: .stream) { req -> Response in
            XCTAssertTrue(serverSawRequest.compareExchange(expected: false, desired: true, ordering: .relaxed).exchanged)

            return Response(body: .init(stream: { writer in
                req.body.drain { stream in
                    switch stream {
                    case .buffer(let bytes):
                        numberOfTimesTheServerGotOfferedBytes.wrappingIncrement(ordering: .relaxed)
                        bytesTheServerSaw.wrappingIncrement(by: bytes.readableBytes, ordering: .relaxed)
                    case .end:
                        XCTFail("backpressure should prevent us seeing the end of the request.")
                        serverSawEnd.store(true, ordering: .relaxed)
                        writer.write(.end, promise: nil)
                    case .error(let error):
                        writer.write(.error(error), promise: nil)
                    }
                    return allDonePromise.futureResult
                }
            }))
        }

        app.environment.arguments = ["serve"]
        XCTAssertNoThrow(try app.start())

        XCTAssertNotNil(app.http.server.shared.localAddress)
        guard let localAddress = app.http.server.shared.localAddress,
              let ip = localAddress.ipAddress,
              let port = localAddress.port else {
            XCTFail("couldn't get ip/port from \(app.http.server.shared.localAddress.debugDescription)")
            return
        }

        final class ResponseDelegate: HTTPClientResponseDelegate {
            typealias Response = Void

            private let bytesTheClientSent: ManagedAtomic<Int>

            init(bytesTheClientSent: ManagedAtomic<Int>) {
                self.bytesTheClientSent = bytesTheClientSent
            }

            func didFinishRequest(task: HTTPClient.Task<Response>) throws -> Response {
                return ()
            }

            func didSendRequestPart(task: HTTPClient.Task<Response>, _ part: IOData) {
                self.bytesTheClientSent.wrappingIncrement(by: part.readableBytes, ordering: .relaxed)
            }
        }

        let tenMB = ByteBuffer(repeating: 0x41, count: 10 * 1024 * 1024)
        let request = try! HTTPClient.Request(url: "http://\(ip):\(port)/hello",
                                         method: .POST,
                                         headers: [:],
                                         body: .byteBuffer(tenMB))
        let delegate = ResponseDelegate(bytesTheClientSent: bytesTheClientSent)
        XCTAssertThrowsError(try app.http.client.shared.execute(request: request,
                                                                delegate: delegate,
                                                                deadline: .now() + .milliseconds(500)).wait()) { error in
            if let error = error as? HTTPClientError {
                #warning("Fix")
                XCTAssert(error == .readTimeout/* || error == .deadlineExceeded*/)
            } else {
                XCTFail("unexpected error: \(error)")
            }
        }

        XCTAssertEqual(1, numberOfTimesTheServerGotOfferedBytes.load(ordering: .relaxed))
        XCTAssertGreaterThan(tenMB.readableBytes, bytesTheServerSaw.load(ordering: .relaxed))
        XCTAssertGreaterThan(tenMB.readableBytes, bytesTheClientSent.load(ordering: .relaxed))
        XCTAssertEqual(0, bytesTheClientSent.load(ordering: .relaxed)) // We'd only see this if we sent the full 10 MB.
        XCTAssertFalse(serverSawEnd.load(ordering: .relaxed))
        XCTAssertTrue(serverSawRequest.load(ordering: .relaxed))

        allDonePromise.succeed(())
    }

    func testCanOverrideCertValidation() throws {
        guard let clientCertPath = Bundle.module.url(forResource: "expired", withExtension: "crt"),
              let clientKeyPath = Bundle.module.url(forResource: "expired", withExtension: "key") else {
            XCTFail("Cannot load expired cert and associated key")
            return
        }

        let cert = try NIOSSLCertificate(file: clientCertPath.path, format: .pem)
        let key = try NIOSSLPrivateKey(file: clientKeyPath.path, format: .pem)

        let app = Application(.testing)

        app.http.server.configuration.hostname = "127.0.0.1"
        app.http.server.configuration.port = 0

        var serverConfig = TLSConfiguration.makeServerConfiguration(certificateChain: [.certificate(cert)], privateKey: .privateKey(key))
        serverConfig.certificateVerification = .noHostnameVerification

        app.http.server.configuration.tlsConfiguration = serverConfig
        app.http.server.configuration.customCertificateVerifyCallback = { peerCerts, successPromise in
            // This lies and accepts the above cert, which has actually expired.
            XCTAssertEqual(peerCerts, [cert])
            successPromise.succeed(.certificateVerified)

        }

        // We need to disable verification on the client, because the cert we're using has expired, and we want to
        // _send_ a client cert.
        var clientConfig = TLSConfiguration.makeClientConfiguration()
        clientConfig.certificateVerification = .none
        clientConfig.certificateChain = [.certificate(cert)]
        clientConfig.privateKey = .privateKey(key)
        app.http.client.configuration.tlsConfiguration = clientConfig

        app.environment.arguments = ["serve"]

        app.get("hello") { req in
            "world"
        }

        defer { app.shutdown() }
        try app.start()

        XCTAssertNotNil(app.http.server.shared.localAddress)
        guard let localAddress = app.http.server.shared.localAddress,
              let ip = localAddress.ipAddress,
              let port = localAddress.port else {
            XCTFail("couldn't get ip/port from \(app.http.server.shared.localAddress.debugDescription)")
            return
        }

        let request = try HTTPClient.Request(
            url: "https://\(ip):\(port)/hello",
            method: .GET
        )
        let a = try app.http.client.shared.execute(request: request).wait()
        XCTAssertEqual(a.body, ByteBuffer(string: "world"))
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
