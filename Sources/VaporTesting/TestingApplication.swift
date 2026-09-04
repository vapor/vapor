import AsyncHTTPClient
public import Vapor
import NIOPosix
import NIOCore
import NIOFoundationEssentialsCompat
import NIOHTTPTypesHTTP1
import Logging
import NIOHTTP1
import HTTPTypes
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

extension Application {
    public enum Method {
        /// Default option without a socket. Calls the responder directly
        case inMemory
        /// Runs a real server and binds to the specified port and address
        case running(hostname: String = "127.0.0.1", port: Int = 0)
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
                return TestingHTTPResponse(
                    status: .init(code: Int(response.status.code)),
                    headers: .init(response.headers, splitCookie: false),
                    body: try await request.responseBodyCollection.apply(to: .init(stream: { writer in
                        for try await chunk in response.body {
                            try await writer.write(chunk.readableBytesView)
                        }
                    })),
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
            // Captured before `request` is shadowed by the `Request` built below.
            let collection = request.responseBodyCollection
            var headers = request.headers
            headers[.contentLength] = request.body.readableBytes.description
            let request = Request(
                method: request.method,
                url: request.url,
                headers: headers,
                collectedBody: request.body.readableBytes == 0 ? nil : request.body,
                remoteAddress: nil,
                contentConfiguration: app.contentConfiguration,
                defaultMaxBodySize: app.routes.defaultMaxBodySize
            )
            let responder: any Responder
            switch self.app.responder {
            case .provided(let provided):
                responder = provided
            case .default:
                responder = DefaultResponder(routes: app.routes, middleware: app.middleware.resolve())
            }
            let res = try await responder.respond(to: request)
            return TestingHTTPResponse(
                status: res.status,
                headers: res.headers,
                body: try await collection.apply(to: res.body),
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


extension ResponseBodyCollection {
    /// Resolves a response body according to this policy.
    ///
    /// `.collect` reads it up front, so the body handed to a test is an ordinary in-memory one and
    /// the request completes rather than being cancelled when nothing reads it. `.stream` hands it
    /// over untouched.
    func apply(to body: Response.Body) async throws -> Response.Body {
        switch self {
        case .stream:
            return body
        case .collect(let max):
            var body = body
            return .init(data: try await body.collect(max: max) ?? Data())
        }
    }
}
