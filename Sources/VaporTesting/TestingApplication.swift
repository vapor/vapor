import AsyncHTTPClient
public import Vapor
import NIOPosix
import NIOCore
import NIOHTTPTypesHTTP1
import Logging
import NIOHTTP1
import HTTPTypes

extension Application {
    public enum Method {
        case inMemory
        /// Runs the app on an ephemeral port.
        ///
        /// Bound by IP rather than by name: `localhost` resolves to `::1` before `127.0.0.1`, so a
        /// name here makes every test that uses it depend on the host's IPv6 loopback. Use
        /// ``running(hostname:port:)`` to bind something else.
        public static var running: Method {
            return .running(hostname: "127.0.0.1", port: 0)
        }
        public static func running(port: Int) -> Self {
            .running(hostname: "127.0.0.1", port: port)
        }
        case running(hostname: String, port: Int)
    }

    package struct Live: Sendable {
        let app: Application
        let port: Int
        let hostname: String

        package init(app: Application, hostname: String = "127.0.0.1", port: Int) throws {
            self.app = app
            self.hostname = hostname
            self.port = port
        }

        package func performTest(request: TestingHTTPRequest) async throws -> TestingHTTPResponse {
            return try await withRunningApp(app: app, hostname: self.hostname, portToUse: self.port) { port in
                var request = request
                request.url.host = self.hostname
                request.url.port = port
                return try await makeRequest(request)
            }
        }

        package func makeRequest(_ request: TestingHTTPRequest) async throws -> TestingHTTPResponse {
            let client = HTTPClient.shared

            do {
                var path = request.url.path
                path = path.hasPrefix("/") ? path : "/\(path)"
#warning("This needs tidying up")
                let portToUse = request.url.port ?? self.port
                let hostnameToUse = request.url.host ?? self.hostname
                var url = "http://\(hostnameToUse):\(portToUse)\(path)"
                if let query = request.url.query {
                    url += "?\(query)"
                }
                var clientRequest = HTTPClientRequest(url: url)
                clientRequest.method = .init(request.method)
                clientRequest.headers = .init(request.headers)
                clientRequest.body = .bytes(request.body)
                let response = try await client.execute(clientRequest, timeout: .seconds(30))
                // Collect up to 1MB
                let responseBody = try await response.body.collect(upTo: 1024 * 1024)
                return TestingHTTPResponse(
                    status: .init(code: Int(response.status.code)),
                    headers: .init(response.headers, splitCookie: false),
                    body: responseBody,
                    contentConfiguration: self.app.contentConfiguration
                )
            } catch {
                Logger.current.info("Caught error in test", metadata: ["error": "\(String(describing: error))"])
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
            try await makeRequest(request)
        }

        package func makeRequest(_ request: TestingHTTPRequest) async throws -> TestingHTTPResponse {
            var headers = request.headers
            headers[.contentLength] = request.body.readableBytes.description
            let request = Request(
                application: app,
                method: request.method,
                url: request.url,
                headers: headers,
                collectedBody: request.body.readableBytes == 0 ? nil : request.body,
                remoteAddress: nil
            )
            let responder: any Responder
            switch self.app.responder {
            case .provided(let provided):
                responder = provided
            case .default:
                responder = DefaultResponder(routes: app.routes, middleware: app.middleware.resolve())
            }
            var res = try await responder.respond(to: request)
            let body = if let collectBody = try await res.body.collect() {
                ByteBuffer(bytes: collectBody)
            } else {
                ByteBufferAllocator().buffer(capacity: 0)
            }
            return TestingHTTPResponse(
                status: res.status,
                headers: res.headers,
                body: body,
                contentConfiguration: self.app.contentConfiguration
            )
        }
    }
}

package enum TestErrors: Error {
    case portNotSet
    case missingPort
    case missingHostname
}
