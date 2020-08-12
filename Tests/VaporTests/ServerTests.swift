import Vapor
import XCTest
import protocol AsyncHTTPClient.HTTPClientResponseDelegate

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

        let res = try app.client.get("http://127.0.0.1:8123/foo").wait()
        XCTAssertEqual(res.body?.string, "bar")
    }

    func testConfigureHTTPDecompressionLimit() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

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
        let res = try app.client.post("http://localhost:8080/gzip") { req in
            req.headers.replaceOrAdd(name: .contentEncoding, value: "gzip")
            req.body = smallBody
        }.wait()
        XCTAssertEqual(res.body?.string, smallOrigString)

        // Big payload should be hard-rejected. We can't test for the raw NIOHTTPDecompression.DecompressionError.limit error here because
        // protocol decoding errors are only ever logged and can't be directly caught.
        do {
            _ = try app.client.post("http://localhost:8080/gzip") { req in
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
