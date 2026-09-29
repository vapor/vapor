#if Compression
import AsyncHTTPClient
import Foundation
import HTTPTypes
import RoutingKit
import Testing
import Vapor
import VaporTesting

@Suite("Compression Middleware Registration", .timeLimit(.minutes(1)))
struct CompressionMiddlewareTests {
    private static let plaintext = Data("Hello, world!".utf8)
    private static let gzip = Data(base64Encoded: "H4sIAAAAAAAAE/NIzcnJ11Eozy/KSVEEAObG5usNAAAA")!
    private static let receivedBody = HTTPField.Name("received-body")!
    private static let receivedEncoding = HTTPField.Name("received-encoding")!

    private static func echo(_ request: Request) async throws -> Response {
        let body = try await request.body.collect() ?? Data()
        var headers = HTTPFields()
        headers[Self.receivedBody] = body.base64EncodedString()
        headers[Self.receivedEncoding] = request.headers[.contentEncoding]
        headers.contentType = .plainText
        return Response(headers: headers, body: .init(data: body))
    }

    private func withRawClient(
        app: Application, method: Application.Method,
        test: (any TestClient) async throws -> Void
    ) async throws {
        var configuration = HTTPClient.Configuration()
        configuration.decompression = .disabled
        try await app.testing(method, options: .live(clientOptions: .init(configuration: configuration)), test)
    }

    @Test(
        "Registration independently enables each direction; configuration alone does not",
        arguments: [false, true], [(false, false), (true, false), (false, true), (true, true)])
    func registration(live: Bool, directions: (Bool, Bool)) async throws {
        let (decompressRequests, compressResponses) = directions
        try await withApp { app in
            app.serverConfiguration.requestDecompression = .init(limit: .size(Self.plaintext.count))
            app.serverConfiguration.responseCompression = .init(mediaTypes: .excluding(.none))
            if compressResponses {
                app.middleware.use(app.makeResponseCompressionMiddleware(), at: .beginning)
            }
            if decompressRequests {
                app.middleware.use(app.makeRequestDecompressionMiddleware())
            }
            app.post("echo", use: Self.echo)
            // The configured policy allows even content types excluded by the default policy.
            app.get("image") { _ in
                Response(headers: [.contentType: "image/png"], body: .init(data: Self.plaintext))
            }
            try await self.withRawClient(app: app, method: live ? .running : .inMemory) { client in
                let response = try await client.post("/echo") {
                    $0.headers[.contentEncoding] = "gzip"
                    $0.headers[.acceptEncoding] = "gzip"
                    $0.body = .init(data: Self.gzip)
                }
                let expected = decompressRequests ? Self.plaintext : Self.gzip
                #expect(response.status == .ok)
                #expect(response.headers[Self.receivedBody] == expected.base64EncodedString())
                #expect(response.headers[Self.receivedEncoding] == (decompressRequests ? nil : "gzip"))
                #expect(response.headers[.contentEncoding] == (compressResponses ? "gzip" : nil))
                let body = try await response.body.data()
                if !compressResponses { #expect(body == expected) }
                let image = try await client.get("/image") { $0.headers[.acceptEncoding] = "gzip" }
                #expect(image.headers[.contentEncoding] == (compressResponses ? "gzip" : nil))
            }
        }
    }

    @Test("Middleware defaults work without configuration", arguments: [false, true])
    func defaults(live: Bool) async throws {
        try await withApp { app in
            app.middleware.use(ResponseCompressionMiddleware(), at: .beginning)
            app.middleware.use(RequestDecompressionMiddleware())
            app.post("echo", use: Self.echo)
            try await self.withRawClient(app: app, method: live ? .running : .inMemory) { client in
                let response = try await client.post("/echo") {
                    $0.headers[.contentEncoding] = "gzip"
                    $0.headers[.acceptEncoding] = "gzip"
                    $0.body = .init(data: Self.gzip)
                }
                #expect(response.status == .ok)
                #expect(response.headers[Self.receivedBody] == Self.plaintext.base64EncodedString())
                #expect(response.headers[.contentEncoding] == "gzip")

                // This fixture expands by more than the default 25:1 limit.
                let large = Data(
                    base64Encoded: "H4sIAAAAAAAC/+3JsREAIAgAsVWwdxD2EDo8PChc3yUsP23UI3LKyn3Ku93kZoUNUYIgCIIgCIIgiL/xAAxnObaADAAA")!
                let rejected = try await client.post("/echo") {
                    $0.headers[.contentEncoding] = "gzip"
                    $0.headers[.acceptEncoding] = "gzip"
                    $0.body = .init(data: large)
                }
                #expect(rejected.status == .contentTooLarge)
                #expect(rejected.headers[.contentEncoding] == "gzip")
                let missing = try await client.get("/missing") { $0.headers[.acceptEncoding] = "gzip" }
                #expect(missing.status == .notFound)
                #expect(missing.headers[.contentEncoding] == "gzip")
            }
        }
    }

    @Test("Middleware can be scoped to a route group", arguments: [false, true])
    func routeGroup(live: Bool) async throws {
        try await withApp { app in
            let group = app.grouped(app.makeResponseCompressionMiddleware(), app.makeRequestDecompressionMiddleware())
            group.post("scoped", use: Self.echo)
            app.post("plain", use: Self.echo)
            try await self.withRawClient(app: app, method: live ? .running : .inMemory) { client in
                for (path, enabled) in [("/scoped", true), ("/plain", false)] {
                    let response = try await client.post(URI(string: path)) {
                        $0.headers[.contentEncoding] = "gzip"
                        $0.headers[.acceptEncoding] = "gzip"
                        $0.body = .init(data: Self.gzip)
                    }
                    #expect(response.status == .ok)
                    #expect(response.headers[.contentEncoding] == (enabled ? "gzip" : nil))
                    #expect(response.headers[Self.receivedBody] == (enabled ? Self.plaintext : Self.gzip).base64EncodedString())
                }
            }
        }
    }
}
#endif
