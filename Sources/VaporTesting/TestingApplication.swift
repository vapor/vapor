import AsyncHTTPClient
import Vapor
import NIOPosix
import NIOCore

extension Application {
    public enum Method {
        case inMemory
        public static var running: Method {
            return .running(hostname:"localhost", port: 0)
        }
        public static func running(port: Int) -> Self {
            .running(hostname: "localhost", port: port)
        }
        case running(hostname: String, port: Int)
    }

    package struct Live: Sendable {
        let app: Application
        let port: Int
        let hostname: String

        package init(app: Application, hostname: String = "localhost", port: Int) throws {
            self.app = app
            self.hostname = hostname
            self.port = port
        }

        package func performTest(request: TestingHTTPRequest) async throws -> TestingHTTPResponse {
            app.logger.info("Will perform test in Live app")
            return try await withThrowingTaskGroup(of: Void.self) { group in
                app.serverConfiguration.address = .hostname(self.hostname, port: self.port)
                let portPromise = Promise<Int>()
                app.serverConfiguration.onServerRunning = { channel in
                    guard let port = channel.localAddress?.port else {
                        portPromise.fail(TestErrors.portNotSet)
                        return
                    }
                    portPromise.complete(port)
                }


                group.addTask {
                    app.logger.info("Will attempt to start server")
                    do {
                        try await app.server.start()
                    } catch {
                        print("tsentrsintersntirsteni")
                    }
                }

                let client = HTTPClient(eventLoopGroup: MultiThreadedEventLoopGroup.singleton)

                do {
                    var path = request.url.path
                    path = path.hasPrefix("/") ? path : "/\(path)"

                    let actualPort: Int

                    app.logger.info("Will wait for port")
                    if self.port == 0 {
                        actualPort = try await portPromise.wait()
                    } else {
                        actualPort = self.port
                    }

                    var url = "http://\(self.hostname):\(actualPort)\(path)"
                    if let query = request.url.query {
                        url += "?\(query)"
                    }
                    var clientRequest = HTTPClientRequest(url: url)
                    clientRequest.method = .init(request.method)
                    clientRequest.headers = .init(request.headers)
                    clientRequest.body = .bytes(request.body)
                    app.logger.info("Sending request in test")
                    let response = try await client.execute(clientRequest, timeout: .seconds(30))
                    app.logger.info("Received response in test")
                    // Collect up to 1MB
                    let responseBody = try await response.body.collect(upTo: 1024 * 1024)
                    app.logger.info("Collected response body in test, shutting client down")
                    try await client.shutdown()
                    app.logger.info("Client shutdown, shutting server down")
                    try await app.server.shutdown()
                    app.logger.info("Server shutdown, returning response")
                    return TestingHTTPResponse(
                        status: .init(code: Int(response.status.code)),
                        headers: .init(response.headers, splitCookie: false),
                        body: responseBody,
                        contentConfiguration: self.app.contentConfiguration
                    )
                } catch {
                    #warning("We should probably use a service group here and trigger a graceful shutdown")
                    app.logger.info("Caught error in test", metadata: ["error": "\(String(describing: error))"])
                    try? await client.shutdown()
                    try? await app.server.shutdown()
                    throw error
                }
            }
        }
    }

    package struct InMemory: Sendable {
        let app: Application
        package init(app: Application) throws {
            self.app = app
        }

        @discardableResult
        package func performTest(
            request: TestingHTTPRequest
        ) async throws -> TestingHTTPResponse {
            var headers = request.headers
            headers[.contentLength] = request.body.readableBytes.description
            let request = Request(
                application: app,
                method: request.method,
                url: request.url,
                headers: headers,
                collectedBody: request.body.readableBytes == 0 ? nil : request.body,
                remoteAddress: nil,
                logger: app.logger,
                on: self.app.eventLoopGroup.next()
            )
            let res = try await self.app.responder.respond(to: request)
            return try await TestingHTTPResponse(
                status: res.status,
                headers: res.headers,
                body: res.body.collect(on: request.eventLoop).get() ?? ByteBufferAllocator().buffer(capacity: 0),
                contentConfiguration: self.app.contentConfiguration
            )
        }
    }
}

import NIOConcurrencyHelpers

/// Promise type.
package final class Promise<Value: Sendable>: Sendable {
    enum State {
        case blocked([CheckedContinuation<Value, any Error>])
        case unblocked(Value)
        case failed(any Error)
    }

    let state: NIOLockedValueBox<State>

    package init() {
        self.state = .init(.blocked([]))
    }

    /// wait from promise to be completed
    package func wait() async throws -> Value {
        try await withCheckedThrowingContinuation { cont in
            self.state.withLockedValue { state in
                switch state {
                case .blocked(var continuations):
                    continuations.append(cont)
                    state = .blocked(continuations)
                case .unblocked(let value):
                    cont.resume(returning: value)
                case .failed(let error):
                    cont.resume(throwing: error)
                }
            }
        }
    }

    /// complete promise with value
    package func complete(_ value: Value) {
        self.state.withLockedValue { state in
            switch state {
            case .blocked(let continuations):
                for cont in continuations {
                    cont.resume(returning: value)
                }
                state = .unblocked(value)
            default: break
            }
        }
    }

    package func fail(_ error: any Error) {
        self.state.withLockedValue { state in
            switch state {
            case .blocked(let continuations):
                for cont in continuations {
                    cont.resume(throwing: error)
                }
            default: break
            }
        }
    }
}

package enum TestErrors: Error {
    case portNotSet
}
