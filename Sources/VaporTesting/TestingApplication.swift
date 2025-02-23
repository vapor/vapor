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
            try await app.server.start(address: .hostname(self.hostname, port: self.port))
            let client = HTTPClient(eventLoopGroup: MultiThreadedEventLoopGroup.singleton)

            do {
                var path = request.url.path
                path = path.hasPrefix("/") ? path : "/\(path)"

                let actualPort: Int

                if self.port == 0 {
                    guard let portAllocated = app.http.server.shared.localAddress?.port else {
                        throw Abort(.internalServerError, reason: "Failed to get port from local address")
                    }
                    actualPort = portAllocated
                } else {
                    actualPort = self.port
                }

                var url = "http://\(self.hostname):\(actualPort)\(path)"
                if let query = request.url.query {
                    url += "?\(query)"
                }
                var clientRequest = HTTPClientRequest(url: url)
                clientRequest.method = request.method
                clientRequest.headers = request.headers
                clientRequest.body = .bytes(request.body)
                let response = try await client.execute(clientRequest, timeout: .seconds(30))
                // Collect up to 1MB
                let responseBody = try await response.body.collect(upTo: 1024 * 1024)
                try await client.shutdown()
                try await app.server.shutdown()
                return TestingHTTPResponse(
                    status: response.status,
                    headers: response.headers,
                    body: responseBody
                )
            } catch {
                try? await client.shutdown()
                try? await app.server.shutdown()
                throw error
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
            headers.replaceOrAdd(
                name: .contentLength,
                value: request.body.readableBytes.description
            )
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
            let res = try await self.app.responder.respond(to: request).get()
            return try await TestingHTTPResponse(
                status: res.status,
                headers: res.headers,
                body: res.body.collect(on: request.eventLoop).get() ?? ByteBufferAllocator().buffer(capacity: 0)
            )
        }
    }
}
