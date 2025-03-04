import Foundation
import Vapor
import AsyncHTTPClient
import NIOCore
import NIOPosix
import NIOConcurrencyHelpers
import NIOSSL
import Atomics
import Testing
import VaporTesting
import HTTPTypes

let markerHeader = HTTPField.Name(HTTPField.Name.xVaporResponseCompression.description)!

@Suite("Conditional Compression Tests")
struct ConditionalCompressionTests {
    @Suite("Response Compression Parsing Tests")
    struct ConditionalResponseCompressionParsingTests {
        @Test("Test enabling encoding")
        func testEncodingEnable() {
            var headers = HTTPFields()
            headers.responseCompression = .enable
            #expect(headers == [markerHeader : "enable"])
        }

        @Test("Test disabling encoding")
        func testEncodingDisable() {
            var headers = HTTPFields()
            headers.responseCompression = .disable
            #expect(headers == [markerHeader : "disable"])
        }

        @Test("Test Encoding Uses Default")
        func testEncodingUseDefault() {
            var headers = HTTPFields()
            headers.responseCompression = .useDefault
            #expect(headers == [markerHeader : "useDefault"])
        }

        @Test("Test Encoding Unset")
        func testEncodingUnset() {
            var headers = HTTPFields()
            headers.responseCompression = .unset
            #expect(headers == [:])
        }

        @Test("Test Updating Sets Correct Headers")
        func testUpdating() {
            var headers = HTTPFields()
            headers.responseCompression = .enable
            #expect(headers == [markerHeader : "enable"])
            headers.responseCompression = .disable
            #expect(headers == [markerHeader : "disable"])
            headers.responseCompression = .unset
            #expect(headers == [:])
            headers[markerHeader] = "enable"
            headers[markerHeader] = "disable"
            #expect(headers == [markerHeader : "enable", markerHeader : "disable"])
            headers.responseCompression = .disable
            #expect(headers == [markerHeader : "disable"])
        }

        @Test("Test Decoding Unset")
        func testDecodingUnset() {
            let headers: HTTPFields = [:]
            #expect(headers.responseCompression == .unset)
        }

        @Test("Decoding Enabled")
        func testDecodingEnabled() {
            let headers: HTTPFields = [markerHeader : "enable"]
            #expect(headers.responseCompression == .enable)
        }

        @Test("Decoding Disabled")
        func testDecodingDisabled() {
            let headers: HTTPFields = [markerHeader : "disable"]
            #expect(headers.responseCompression == .disable)
        }

        @Test("Test Decoding Use Default")
        func testDecodingUseDefault() {
            let headers: HTTPFields = [markerHeader : "useDefault"]
            #expect(headers.responseCompression == .useDefault)
        }

        @Test("Test Decoding Literal Unset")
        func testDecodingLiteralUnset() {
            let headers: HTTPFields = [markerHeader : "unset"]
            #expect(headers.responseCompression == .unset)
        }

        @Test("Test Decoding Other")
        func testDecodingOther() {
            let headers: HTTPFields = [markerHeader : "other"]
            #expect(headers.responseCompression == .unset)
        }

        @Test("Test Decoding Multiple Valid")
        func testDecodingMultipleValid() {
            let headers: HTTPFields = [markerHeader : "enable", markerHeader : "disable"]
            #expect(headers.responseCompression == .disable)
        }

        @Test("Test Decoding Multiple First Invalid")
        func testDecodingMultipleFirstInvalid() {
            let headers: HTTPFields = [markerHeader : "other", markerHeader : "enable"]
            #expect(headers.responseCompression == .enable)
        }

        @Test("Test Decoding Multiple Last Invalid")
        func testDecodingMultipleLastInvalid() {
            let headers: HTTPFields = [markerHeader : "enable", markerHeader : "other"]
            #expect(headers.responseCompression == .unset)
        }
    }

    @Suite("Response Compression Server Tests")
    struct ConditionalResponseCompressionServerTests {
        func expectCompressed(
            _ configuration: HTTPServerOld.Configuration.ResponseCompressionConfiguration,
            on app: Application,
            sourceLocation: SourceLocation = #_sourceLocation
        ) async throws {
            let port = try #require(app.http.server.shared.localAddress?.port)
            app.http.server.configuration.responseCompression = configuration

            let response = try await app.client.get("http://localhost:\(port)/resource") { request in
                request.headers[.acceptEncoding] = "gzip"
            }
            #expect(response.headers[.contentEncoding] == "gzip", sourceLocation: sourceLocation)
            #expect(response.headers[.contentLength] != "\(compressiblePayload.count)", sourceLocation: sourceLocation)
            #expect(response.body?.string == compressiblePayload, sourceLocation: sourceLocation)
        }

        func expectUncompressed(
            _ configuration: HTTPServerOld.Configuration.ResponseCompressionConfiguration,
            on app: Application,
            sourceLocation: SourceLocation = #_sourceLocation
        ) async throws {
            let port = try #require(app.http.server.shared.localAddress?.port)

            app.http.server.configuration.responseCompression = configuration

            let response = try await app.client.get("http://localhost:\(port)/resource") { request in
                request.headers[.acceptEncoding] = "gzip"
            }
            #expect(response.headers[.contentEncoding] != "gzip", sourceLocation: sourceLocation)
            #expect(response.headers[.contentLength] == "\(compressiblePayload.count)", sourceLocation: sourceLocation)
            #expect(response.body?.string == compressiblePayload, sourceLocation: sourceLocation)
        }

        func withCompressionApp(_ block: (Application) async throws -> Void) async throws {
            try await withApp { app in
                app.http.server.configuration.hostname = "127.0.0.1"
                app.http.server.configuration.port = 0

                app.http.server.configuration.supportVersions = [.one]

                /// Make sure the client doesn't keep the server open by re-using the connection.
                app.http.client.configuration.maximumUsesPerConnection = 1
                app.http.client.configuration.decompression = .enabled(limit: .none)

                try await block(app)
                try await app.server.shutdown()
            }
        }

        @Test("Test Autodetecected Type")
        func testAutoDetectedType() async throws {
            try await withCompressionApp { app in
                app.get("resource") { _ in compressiblePayload }

                try await app.server.start()

                try await expectUncompressed(app.http.server.configuration.responseCompression, on: app) /// Default case
                try await expectUncompressed(.forceDisabled, on: app)
                try await expectUncompressed(.disabled, on: app)
                try await expectCompressed(.enabledForCompressibleTypes, on: app)
                try await expectCompressed(.enabled, on: app)

                try await expectUncompressed(.disabled(allowedTypes: .none, allowRequestOverrides: false), on: app)
                try await expectCompressed(.disabled(allowedTypes: .compressible, allowRequestOverrides: false), on: app)
                try await expectCompressed(.disabled(allowedTypes: .all, allowRequestOverrides: false), on: app)
                try await expectUncompressed(.disabled(allowedTypes: .none, allowRequestOverrides: true), on: app)
                try await expectCompressed(.disabled(allowedTypes: .compressible, allowRequestOverrides: true), on: app)
                try await expectCompressed(.disabled(allowedTypes: .all, allowRequestOverrides: true), on: app)

                try await expectCompressed(.enabled(disallowedTypes: .none, allowRequestOverrides: false), on: app)
                try await expectCompressed(.enabled(disallowedTypes: .incompressible, allowRequestOverrides: false), on: app)
                try await expectUncompressed(.enabled(disallowedTypes: .all, allowRequestOverrides: false), on: app)
                try await expectCompressed(.enabled(disallowedTypes: .none, allowRequestOverrides: true), on: app)
                try await expectCompressed(.enabled(disallowedTypes: .incompressible, allowRequestOverrides: true), on: app)
                try await expectUncompressed(.enabled(disallowedTypes: .all, allowRequestOverrides: true), on: app)
            }
        }

        @Test("Unknown Type")
        func testUnknownType() async throws {
            try await withCompressionApp { app in
                app.get("resource") { request in
                    var headers = HTTPFields()
                    headers.contentType = unknownType /// Not explicitely marked as compressible or not.
                    return try await compressiblePayload.encodeResponse(status: .ok, headers: headers, for: request)
                }

                try await app.server.start()

                try await expectUncompressed(app.http.server.configuration.responseCompression, on: app) /// Default case
                try await expectUncompressed(.forceDisabled, on: app)
                try await expectUncompressed(.disabled, on: app)
                try await expectUncompressed(.enabledForCompressibleTypes, on: app)
                try await expectCompressed(.enabled, on: app)

                try await expectUncompressed(.disabled(allowedTypes: .none, allowRequestOverrides: false), on: app)
                try await expectUncompressed(.disabled(allowedTypes: .compressible, allowRequestOverrides: false), on: app)
                try await expectCompressed(.disabled(allowedTypes: .all, allowRequestOverrides: false), on: app)
                try await expectUncompressed(.disabled(allowedTypes: .none, allowRequestOverrides: true), on: app)
                try await expectUncompressed(.disabled(allowedTypes: .compressible, allowRequestOverrides: true), on: app)
                try await expectCompressed(.disabled(allowedTypes: .all, allowRequestOverrides: true), on: app)

                try await expectCompressed(.enabled(disallowedTypes: .none, allowRequestOverrides: false), on: app)
                try await expectCompressed(.enabled(disallowedTypes: .incompressible, allowRequestOverrides: false), on: app)
                try await expectUncompressed(.enabled(disallowedTypes: .all, allowRequestOverrides: false), on: app)
                try await expectCompressed(.enabled(disallowedTypes: .none, allowRequestOverrides: true), on: app)
                try await expectCompressed(.enabled(disallowedTypes: .incompressible, allowRequestOverrides: true), on: app)
                try await expectUncompressed(.enabled(disallowedTypes: .all, allowRequestOverrides: true), on: app)
            }
        }

        @Test("Test Image")
        func testImage() async throws {
            try await withCompressionApp { app in
                app.get("resource") { request in
                    var headers = HTTPFields()
                    headers.contentType = .png /// PNGs are explicitely called out as incompressible.
                    return try await compressiblePayload.encodeResponse(status: .ok, headers: headers, for: request)
                }

                try await app.server.start()

                try await expectUncompressed(app.http.server.configuration.responseCompression, on: app) /// Default case
                try await expectUncompressed(.forceDisabled, on: app)
                try await expectUncompressed(.disabled, on: app)
                try await expectUncompressed(.enabledForCompressibleTypes, on: app)
                try await expectUncompressed(.enabled, on: app)

                try await expectUncompressed(.disabled(allowedTypes: .none, allowRequestOverrides: false), on: app)
                try await expectUncompressed(.disabled(allowedTypes: .compressible, allowRequestOverrides: false), on: app)
                try await expectCompressed(.disabled(allowedTypes: .all, allowRequestOverrides: false), on: app)
                try await expectUncompressed(.disabled(allowedTypes: .none, allowRequestOverrides: true), on: app)
                try await expectUncompressed(.disabled(allowedTypes: .compressible, allowRequestOverrides: true), on: app)
                try await expectCompressed(.disabled(allowedTypes: .all, allowRequestOverrides: true), on: app)

                try await expectCompressed(.enabled(disallowedTypes: .none, allowRequestOverrides: false), on: app)
                try await expectUncompressed(.enabled(disallowedTypes: .incompressible, allowRequestOverrides: false), on: app)
                try await expectUncompressed(.enabled(disallowedTypes: .all, allowRequestOverrides: false), on: app)
                try await expectCompressed(.enabled(disallowedTypes: .none, allowRequestOverrides: true), on: app)
                try await expectUncompressed(.enabled(disallowedTypes: .incompressible, allowRequestOverrides: true), on: app)
                try await expectUncompressed(.enabled(disallowedTypes: .all, allowRequestOverrides: true), on: app)
            }
        }

        @Test("Test Video")
        func testVideo() async throws {
            try await withCompressionApp { app in
                app.get("resource") { request in
                    var headers = HTTPFields()
                    headers.contentType = .mpeg /// Videos are explicitely called out as incompressible, but as a class.
                    return try await compressiblePayload.encodeResponse(status: .ok, headers: headers, for: request)
                }

                try await app.server.start()

                try await expectUncompressed(app.http.server.configuration.responseCompression, on: app) /// Default case
                try await expectUncompressed(.forceDisabled, on: app)
                try await expectUncompressed(.disabled, on: app)
                try await expectUncompressed(.enabledForCompressibleTypes, on: app)
                try await expectUncompressed(.enabled, on: app)

                try await expectUncompressed(.disabled(allowedTypes: .none, allowRequestOverrides: false), on: app)
                try await expectUncompressed(.disabled(allowedTypes: .compressible, allowRequestOverrides: false), on: app)
                try await expectCompressed(.disabled(allowedTypes: .all, allowRequestOverrides: false), on: app)
                try await expectUncompressed(.disabled(allowedTypes: .none, allowRequestOverrides: true), on: app)
                try await expectUncompressed(.disabled(allowedTypes: .compressible, allowRequestOverrides: true), on: app)
                try await expectCompressed(.disabled(allowedTypes: .all, allowRequestOverrides: true), on: app)

                try await expectCompressed(.enabled(disallowedTypes: .none, allowRequestOverrides: false), on: app)
                try await expectUncompressed(.enabled(disallowedTypes: .incompressible, allowRequestOverrides: false), on: app)
                try await expectUncompressed(.enabled(disallowedTypes: .all, allowRequestOverrides: false), on: app)
                try await expectCompressed(.enabled(disallowedTypes: .none, allowRequestOverrides: true), on: app)
                try await expectUncompressed(.enabled(disallowedTypes: .incompressible, allowRequestOverrides: true), on: app)
                try await expectUncompressed(.enabled(disallowedTypes: .all, allowRequestOverrides: true), on: app)
            }
        }

        @Test("Test Text")
        func testText() async throws {
            try await withCompressionApp { app in
                app.get("resource") { request in
                    var headers = HTTPFields()
                    headers.contentType = .plainText /// Text types are explicitely called out as compressible, but as a class.
                    return try await compressiblePayload.encodeResponse(status: .ok, headers: headers, for: request)
                }

                try await app.server.start()

                try await expectUncompressed(app.http.server.configuration.responseCompression, on: app) /// Default case
                try await expectUncompressed(.forceDisabled, on: app)
                try await expectUncompressed(.disabled, on: app)
                try await expectCompressed(.enabledForCompressibleTypes, on: app)
                try await expectCompressed(.enabled, on: app)

                try await expectUncompressed(.disabled(allowedTypes: .none, allowRequestOverrides: false), on: app)
                try await expectCompressed(.disabled(allowedTypes: .compressible, allowRequestOverrides: false), on: app)
                try await expectCompressed(.disabled(allowedTypes: .all, allowRequestOverrides: false), on: app)
                try await expectUncompressed(.disabled(allowedTypes: .none, allowRequestOverrides: true), on: app)
                try await expectCompressed(.disabled(allowedTypes: .compressible, allowRequestOverrides: true), on: app)
                try await expectCompressed(.disabled(allowedTypes: .all, allowRequestOverrides: true), on: app)

                try await expectCompressed(.enabled(disallowedTypes: .none, allowRequestOverrides: false), on: app)
                try await expectCompressed(.enabled(disallowedTypes: .incompressible, allowRequestOverrides: false), on: app)
                try await expectUncompressed(.enabled(disallowedTypes: .all, allowRequestOverrides: false), on: app)
                try await expectCompressed(.enabled(disallowedTypes: .none, allowRequestOverrides: true), on: app)
                try await expectCompressed(.enabled(disallowedTypes: .incompressible, allowRequestOverrides: true), on: app)
                try await expectUncompressed(.enabled(disallowedTypes: .all, allowRequestOverrides: true), on: app)
            }
        }

        @Test("Test Enabled By Response")
        func testEnabledByResponse() async throws {
            try await withCompressionApp { app in
                app.get("resource") { request in
                    var headers = HTTPFields()
                    headers.contentType = unknownType
                    headers.responseCompression = .enable
                    return try await compressiblePayload.encodeResponse(status: .ok, headers: headers, for: request)
                }

                try await app.server.start()

                try await expectCompressed(app.http.server.configuration.responseCompression, on: app) /// Default case
                try await expectUncompressed(.forceDisabled, on: app)
                try await expectCompressed(.disabled, on: app)
                try await expectCompressed(.enabledForCompressibleTypes, on: app)
                try await expectCompressed(.enabled, on: app)

                try await expectUncompressed(.disabled(allowedTypes: .none, allowRequestOverrides: false), on: app)
                try await expectUncompressed(.disabled(allowedTypes: .compressible, allowRequestOverrides: false), on: app)
                try await expectCompressed(.disabled(allowedTypes: .all, allowRequestOverrides: false), on: app)
                try await expectCompressed(.disabled(allowedTypes: .none, allowRequestOverrides: true), on: app)
                try await expectCompressed(.disabled(allowedTypes: .compressible, allowRequestOverrides: true), on: app)
                try await expectCompressed(.disabled(allowedTypes: .all, allowRequestOverrides: true), on: app)

                try await expectCompressed(.enabled(disallowedTypes: .none, allowRequestOverrides: false), on: app)
                try await expectCompressed(.enabled(disallowedTypes: .incompressible, allowRequestOverrides: false), on: app)
                try await expectCompressed(.enabled(disallowedTypes: .all, allowRequestOverrides: false), on: app)
                try await expectCompressed(.enabled(disallowedTypes: .none, allowRequestOverrides: true), on: app)
                try await expectCompressed(.enabled(disallowedTypes: .incompressible, allowRequestOverrides: true), on: app)
                try await expectCompressed(.enabled(disallowedTypes: .all, allowRequestOverrides: true), on: app)
            }
        }

        @Test("Test Disabled By Response")
        func testDisabledByResponse() async throws {
            try await withCompressionApp { app in
                app.get("resource") { request in
                    var headers = HTTPFields()
                    headers.contentType = unknownType
                    headers.responseCompression = .disable
                    return try await compressiblePayload.encodeResponse(status: .ok, headers: headers, for: request)
                }

                try await app.server.start()

                try await expectUncompressed(app.http.server.configuration.responseCompression, on: app) /// Default case
                try await expectUncompressed(.forceDisabled, on: app)
                try await expectUncompressed(.disabled, on: app)
                try await expectUncompressed(.enabledForCompressibleTypes, on: app)
                try await expectUncompressed(.enabled, on: app)

                try await expectUncompressed(.disabled(allowedTypes: .none, allowRequestOverrides: false), on: app)
                try await expectUncompressed(.disabled(allowedTypes: .compressible, allowRequestOverrides: false), on: app)
                try await expectCompressed(.disabled(allowedTypes: .all, allowRequestOverrides: false), on: app)
                try await expectUncompressed(.disabled(allowedTypes: .none, allowRequestOverrides: true), on: app)
                try await expectUncompressed(.disabled(allowedTypes: .compressible, allowRequestOverrides: true), on: app)
                try await expectUncompressed(.disabled(allowedTypes: .all, allowRequestOverrides: true), on: app)

                try await expectUncompressed(.enabled(disallowedTypes: .none, allowRequestOverrides: false), on: app)
                try await expectUncompressed(.enabled(disallowedTypes: .incompressible, allowRequestOverrides: false), on: app)
                try await expectUncompressed(.enabled(disallowedTypes: .all, allowRequestOverrides: false), on: app)
                try await expectUncompressed(.enabled(disallowedTypes: .none, allowRequestOverrides: true), on: app)
                try await expectUncompressed(.enabled(disallowedTypes: .incompressible, allowRequestOverrides: true), on: app)
                try await expectUncompressed(.enabled(disallowedTypes: .all, allowRequestOverrides: true), on: app)
            }
        }

        @Test("Test Force Enabled By Response")
        func testForceEnabledByResponse() async throws {
            try await withCompressionApp { app in
                app.responseCompression(.disable).get("resource") { request in
                    var headers = HTTPFields()
                    headers.contentType = unknownType
                    headers.responseCompression = .enable
                    return try await compressiblePayload.encodeResponse(status: .ok, headers: headers, for: request)
                }

                try await app.server.start()

                try await expectCompressed(app.http.server.configuration.responseCompression, on: app) /// Default case
                try await expectUncompressed(.forceDisabled, on: app)
                try await expectCompressed(.disabled, on: app)
                try await expectCompressed(.enabledForCompressibleTypes, on: app)
                try await expectCompressed(.enabled, on: app)

                try await expectUncompressed(.disabled(allowedTypes: .none, allowRequestOverrides: false), on: app)
                try await expectUncompressed(.disabled(allowedTypes: .compressible, allowRequestOverrides: false), on: app)
                try await expectCompressed(.disabled(allowedTypes: .all, allowRequestOverrides: false), on: app)
                try await expectCompressed(.disabled(allowedTypes: .none, allowRequestOverrides: true), on: app)
                try await expectCompressed(.disabled(allowedTypes: .compressible, allowRequestOverrides: true), on: app)
                try await expectCompressed(.disabled(allowedTypes: .all, allowRequestOverrides: true), on: app)

                try await expectCompressed(.enabled(disallowedTypes: .none, allowRequestOverrides: false), on: app)
                try await expectCompressed(.enabled(disallowedTypes: .incompressible, allowRequestOverrides: false), on: app)
                try await expectCompressed(.enabled(disallowedTypes: .all, allowRequestOverrides: false), on: app)
                try await expectCompressed(.enabled(disallowedTypes: .none, allowRequestOverrides: true), on: app)
                try await expectCompressed(.enabled(disallowedTypes: .incompressible, allowRequestOverrides: true), on: app)
                try await expectCompressed(.enabled(disallowedTypes: .all, allowRequestOverrides: true), on: app)
            }
        }

        @Test("Test Force Disabled By Response")
        func testForceDisabledByResponse() async throws {
            try await withCompressionApp { app in
                app.responseCompression(.enable).get("resource") { request in
                    var headers = HTTPFields()
                    headers.contentType = unknownType
                    headers.responseCompression = .disable
                    return try await compressiblePayload.encodeResponse(status: .ok, headers: headers, for: request)
                }

                try await app.server.start()

                try await expectUncompressed(app.http.server.configuration.responseCompression, on: app) /// Default case
                try await expectUncompressed(.forceDisabled, on: app)
                try await expectUncompressed(.disabled, on: app)
                try await expectUncompressed(.enabledForCompressibleTypes, on: app)
                try await expectUncompressed(.enabled, on: app)

                try await expectUncompressed(.disabled(allowedTypes: .none, allowRequestOverrides: false), on: app)
                try await expectUncompressed(.disabled(allowedTypes: .compressible, allowRequestOverrides: false), on: app)
                try await expectCompressed(.disabled(allowedTypes: .all, allowRequestOverrides: false), on: app)
                try await expectUncompressed(.disabled(allowedTypes: .none, allowRequestOverrides: true), on: app)
                try await expectUncompressed(.disabled(allowedTypes: .compressible, allowRequestOverrides: true), on: app)
                try await expectUncompressed(.disabled(allowedTypes: .all, allowRequestOverrides: true), on: app)

                try await expectUncompressed(.enabled(disallowedTypes: .none, allowRequestOverrides: false), on: app)
                try await expectUncompressed(.enabled(disallowedTypes: .incompressible, allowRequestOverrides: false), on: app)
                try await expectUncompressed(.enabled(disallowedTypes: .all, allowRequestOverrides: false), on: app)
                try await expectUncompressed(.enabled(disallowedTypes: .none, allowRequestOverrides: true), on: app)
                try await expectUncompressed(.enabled(disallowedTypes: .incompressible, allowRequestOverrides: true), on: app)
                try await expectUncompressed(.enabled(disallowedTypes: .all, allowRequestOverrides: true), on: app)
            }
        }

        @Test("Test Enabled By Route")
        func testEnabledByRoute() async throws {
            try await withCompressionApp { app in
                app.responseCompression(.enable).get("resource") { request in
                    var headers = HTTPFields()
                    headers.contentType = unknownType
                    return try await compressiblePayload.encodeResponse(status: .ok, headers: headers, for: request)
                }

                try await app.server.start()

                try await expectCompressed(app.http.server.configuration.responseCompression, on: app) /// Default case
                try await expectUncompressed(.forceDisabled, on: app)
                try await expectCompressed(.disabled, on: app)
                try await expectCompressed(.enabledForCompressibleTypes, on: app)
                try await expectCompressed(.enabled, on: app)

                try await expectUncompressed(.disabled(allowedTypes: .none, allowRequestOverrides: false), on: app)
                try await expectUncompressed(.disabled(allowedTypes: .compressible, allowRequestOverrides: false), on: app)
                try await expectCompressed(.disabled(allowedTypes: .all, allowRequestOverrides: false), on: app)
                try await expectCompressed(.disabled(allowedTypes: .none, allowRequestOverrides: true), on: app)
                try await expectCompressed(.disabled(allowedTypes: .compressible, allowRequestOverrides: true), on: app)
                try await expectCompressed(.disabled(allowedTypes: .all, allowRequestOverrides: true), on: app)

                try await expectCompressed(.enabled(disallowedTypes: .none, allowRequestOverrides: false), on: app)
                try await expectCompressed(.enabled(disallowedTypes: .incompressible, allowRequestOverrides: false), on: app)
                try await expectCompressed(.enabled(disallowedTypes: .all, allowRequestOverrides: false), on: app)
                try await expectCompressed(.enabled(disallowedTypes: .none, allowRequestOverrides: true), on: app)
                try await expectCompressed(.enabled(disallowedTypes: .incompressible, allowRequestOverrides: true), on: app)
                try await expectCompressed(.enabled(disallowedTypes: .all, allowRequestOverrides: true), on: app)
            }
        }

        @Test("Tset Disabled By Route")
        func testDisabledByRoute() async throws {
            try await withCompressionApp { app in
                app.responseCompression(.disable).get("resource") { request in
                    var headers = HTTPFields()
                    headers.contentType = unknownType
                    return try await compressiblePayload.encodeResponse(status: .ok, headers: headers, for: request)
                }

                try await app.server.start()

                try await expectUncompressed(app.http.server.configuration.responseCompression, on: app) /// Default case
                try await expectUncompressed(.forceDisabled, on: app)
                try await expectUncompressed(.disabled, on: app)
                try await expectUncompressed(.enabledForCompressibleTypes, on: app)
                try await expectUncompressed(.enabled, on: app)

                try await expectUncompressed(.disabled(allowedTypes: .none, allowRequestOverrides: false), on: app)
                try await expectUncompressed(.disabled(allowedTypes: .compressible, allowRequestOverrides: false), on: app)
                try await expectCompressed(.disabled(allowedTypes: .all, allowRequestOverrides: false), on: app)
                try await expectUncompressed(.disabled(allowedTypes: .none, allowRequestOverrides: true), on: app)
                try await expectUncompressed(.disabled(allowedTypes: .compressible, allowRequestOverrides: true), on: app)
                try await expectUncompressed(.disabled(allowedTypes: .all, allowRequestOverrides: true), on: app)

                try await expectUncompressed(.enabled(disallowedTypes: .none, allowRequestOverrides: false), on: app)
                try await expectUncompressed(.enabled(disallowedTypes: .incompressible, allowRequestOverrides: false), on: app)
                try await expectUncompressed(.enabled(disallowedTypes: .all, allowRequestOverrides: false), on: app)
                try await expectUncompressed(.enabled(disallowedTypes: .none, allowRequestOverrides: true), on: app)
                try await expectUncompressed(.enabled(disallowedTypes: .incompressible, allowRequestOverrides: true), on: app)
                try await expectUncompressed(.enabled(disallowedTypes: .all, allowRequestOverrides: true), on: app)
            }
        }

        @Test("Test Disable By Route But Reset")
        func testDisabledByRouteButReset() async throws {
            try await withCompressionApp { app in
                app.responseCompression(.disable).responseCompression(.useDefault).get("resource") { request in
                    var headers = HTTPFields()
                    headers.contentType = unknownType
                    return try await compressiblePayload.encodeResponse(status: .ok, headers: headers, for: request)
                }

                try await app.server.start()

                try await expectUncompressed(app.http.server.configuration.responseCompression, on: app) /// Default case
                try await expectUncompressed(.forceDisabled, on: app)
                try await expectUncompressed(.disabled, on: app)
                try await expectUncompressed(.enabledForCompressibleTypes, on: app)
                try await expectCompressed(.enabled, on: app)

                try await expectUncompressed(.disabled(allowedTypes: .none, allowRequestOverrides: false), on: app)
                try await expectUncompressed(.disabled(allowedTypes: .compressible, allowRequestOverrides: false), on: app)
                try await expectCompressed(.disabled(allowedTypes: .all, allowRequestOverrides: false), on: app)
                try await expectUncompressed(.disabled(allowedTypes: .none, allowRequestOverrides: true), on: app)
                try await expectUncompressed(.disabled(allowedTypes: .compressible, allowRequestOverrides: true), on: app)
                try await expectCompressed(.disabled(allowedTypes: .all, allowRequestOverrides: true), on: app)

                try await expectCompressed(.enabled(disallowedTypes: .none, allowRequestOverrides: false), on: app)
                try await expectCompressed(.enabled(disallowedTypes: .incompressible, allowRequestOverrides: false), on: app)
                try await expectUncompressed(.enabled(disallowedTypes: .all, allowRequestOverrides: false), on: app)
                try await expectCompressed(.enabled(disallowedTypes: .none, allowRequestOverrides: true), on: app)
                try await expectCompressed(.enabled(disallowedTypes: .incompressible, allowRequestOverrides: true), on: app)
                try await expectUncompressed(.enabled(disallowedTypes: .all, allowRequestOverrides: true), on: app)
            }
        }

        @Test("Test Enabled By ROute But Reset")
        func testEnabledByRouteButReset() async throws {
            try await withCompressionApp { app in
                app.responseCompression(.enable).responseCompression(.useDefault).get("resource") { request in
                    var headers = HTTPFields()
                    headers.contentType = unknownType
                    return try await compressiblePayload.encodeResponse(status: .ok, headers: headers, for: request)
                }

                try await app.server.start()

                try await expectUncompressed(app.http.server.configuration.responseCompression, on: app) /// Default case
                try await expectUncompressed(.forceDisabled, on: app)
                try await expectUncompressed(.disabled, on: app)
                try await expectUncompressed(.enabledForCompressibleTypes, on: app)
                try await expectCompressed(.enabled, on: app)

                try await expectUncompressed(.disabled(allowedTypes: .none, allowRequestOverrides: false), on: app)
                try await expectUncompressed(.disabled(allowedTypes: .compressible, allowRequestOverrides: false), on: app)
                try await expectCompressed(.disabled(allowedTypes: .all, allowRequestOverrides: false), on: app)
                try await expectUncompressed(.disabled(allowedTypes: .none, allowRequestOverrides: true), on: app)
                try await expectUncompressed(.disabled(allowedTypes: .compressible, allowRequestOverrides: true), on: app)
                try await expectCompressed(.disabled(allowedTypes: .all, allowRequestOverrides: true), on: app)

                try await expectCompressed(.enabled(disallowedTypes: .none, allowRequestOverrides: false), on: app)
                try await expectCompressed(.enabled(disallowedTypes: .incompressible, allowRequestOverrides: false), on: app)
                try await expectUncompressed(.enabled(disallowedTypes: .all, allowRequestOverrides: false), on: app)
                try await expectCompressed(.enabled(disallowedTypes: .none, allowRequestOverrides: true), on: app)
                try await expectCompressed(.enabled(disallowedTypes: .incompressible, allowRequestOverrides: true), on: app)
                try await expectUncompressed(.enabled(disallowedTypes: .all, allowRequestOverrides: true), on: app)
            }
        }

        @Test("Test Disabled By Route Reset By Response")
        func testDisabledByRouteResetByResponse() async throws {
            try await withCompressionApp { app in
                app.responseCompression(.disable).get("resource") { request in
                    var headers = HTTPFields()
                    headers.responseCompression = .useDefault
                    headers.contentType = unknownType
                    return try await compressiblePayload.encodeResponse(status: .ok, headers: headers, for: request)
                }

                try await app.server.start()

                try await expectUncompressed(app.http.server.configuration.responseCompression, on: app) /// Default case
                try await expectUncompressed(.forceDisabled, on: app)
                try await expectUncompressed(.disabled, on: app)
                try await expectUncompressed(.enabledForCompressibleTypes, on: app)
                try await expectCompressed(.enabled, on: app)

                try await expectUncompressed(.disabled(allowedTypes: .none, allowRequestOverrides: false), on: app)
                try await expectUncompressed(.disabled(allowedTypes: .compressible, allowRequestOverrides: false), on: app)
                try await expectCompressed(.disabled(allowedTypes: .all, allowRequestOverrides: false), on: app)
                try await expectUncompressed(.disabled(allowedTypes: .none, allowRequestOverrides: true), on: app)
                try await expectUncompressed(.disabled(allowedTypes: .compressible, allowRequestOverrides: true), on: app)
                try await expectCompressed(.disabled(allowedTypes: .all, allowRequestOverrides: true), on: app)

                try await expectCompressed(.enabled(disallowedTypes: .none, allowRequestOverrides: false), on: app)
                try await expectCompressed(.enabled(disallowedTypes: .incompressible, allowRequestOverrides: false), on: app)
                try await expectUncompressed(.enabled(disallowedTypes: .all, allowRequestOverrides: false), on: app)
                try await expectCompressed(.enabled(disallowedTypes: .none, allowRequestOverrides: true), on: app)
                try await expectCompressed(.enabled(disallowedTypes: .incompressible, allowRequestOverrides: true), on: app)
                try await expectUncompressed(.enabled(disallowedTypes: .all, allowRequestOverrides: true), on: app)
            }
        }

        @Test("Test Enabled By Route Reset By Response")
        func testEnabledByRouteResetByResponse() async throws {
            try await withCompressionApp { app in
                app.responseCompression(.enable).get("resource") { request in
                    var headers = HTTPFields()
                    headers.responseCompression = .useDefault
                    headers.contentType = unknownType
                    return try await compressiblePayload.encodeResponse(status: .ok, headers: headers, for: request)
                }

                try await app.server.start()

                try await expectUncompressed(app.http.server.configuration.responseCompression, on: app) /// Default case
                try await expectUncompressed(.forceDisabled, on: app)
                try await expectUncompressed(.disabled, on: app)
                try await expectUncompressed(.enabledForCompressibleTypes, on: app)
                try await expectCompressed(.enabled, on: app)

                try await expectUncompressed(.disabled(allowedTypes: .none, allowRequestOverrides: false), on: app)
                try await expectUncompressed(.disabled(allowedTypes: .compressible, allowRequestOverrides: false), on: app)
                try await expectCompressed(.disabled(allowedTypes: .all, allowRequestOverrides: false), on: app)
                try await expectUncompressed(.disabled(allowedTypes: .none, allowRequestOverrides: true), on: app)
                try await expectUncompressed(.disabled(allowedTypes: .compressible, allowRequestOverrides: true), on: app)
                try await expectCompressed(.disabled(allowedTypes: .all, allowRequestOverrides: true), on: app)

                try await expectCompressed(.enabled(disallowedTypes: .none, allowRequestOverrides: false), on: app)
                try await expectCompressed(.enabled(disallowedTypes: .incompressible, allowRequestOverrides: false), on: app)
                try await expectUncompressed(.enabled(disallowedTypes: .all, allowRequestOverrides: false), on: app)
                try await expectCompressed(.enabled(disallowedTypes: .none, allowRequestOverrides: true), on: app)
                try await expectCompressed(.enabled(disallowedTypes: .incompressible, allowRequestOverrides: true), on: app)
                try await expectUncompressed(.enabled(disallowedTypes: .all, allowRequestOverrides: true), on: app)
            }
        }

        @Test("Test Noops Disabled By Route But Reset")
        func testNoopsDisabledByRouteButReset() async throws {
            try await withCompressionApp { app in
                app.responseCompression(.unset).responseCompression(.disable).responseCompression(.unset).responseCompression(.useDefault).responseCompression(.unset).get("resource") { request in
                    var headers = HTTPFields()
                    headers.contentType = unknownType
                    return try await compressiblePayload.encodeResponse(status: .ok, headers: headers, for: request)
                }

                try await app.server.start()

                try await expectUncompressed(app.http.server.configuration.responseCompression, on: app) /// Default case
                try await expectUncompressed(.forceDisabled, on: app)
                try await expectUncompressed(.disabled, on: app)
                try await expectUncompressed(.enabledForCompressibleTypes, on: app)
                try await expectCompressed(.enabled, on: app)

                try await expectUncompressed(.disabled(allowedTypes: .none, allowRequestOverrides: false), on: app)
                try await expectUncompressed(.disabled(allowedTypes: .compressible, allowRequestOverrides: false), on: app)
                try await expectCompressed(.disabled(allowedTypes: .all, allowRequestOverrides: false), on: app)
                try await expectUncompressed(.disabled(allowedTypes: .none, allowRequestOverrides: true), on: app)
                try await expectUncompressed(.disabled(allowedTypes: .compressible, allowRequestOverrides: true), on: app)
                try await expectCompressed(.disabled(allowedTypes: .all, allowRequestOverrides: true), on: app)

                try await expectCompressed(.enabled(disallowedTypes: .none, allowRequestOverrides: false), on: app)
                try await expectCompressed(.enabled(disallowedTypes: .incompressible, allowRequestOverrides: false), on: app)
                try await expectUncompressed(.enabled(disallowedTypes: .all, allowRequestOverrides: false), on: app)
                try await expectCompressed(.enabled(disallowedTypes: .none, allowRequestOverrides: true), on: app)
                try await expectCompressed(.enabled(disallowedTypes: .incompressible, allowRequestOverrides: true), on: app)
                try await expectUncompressed(.enabled(disallowedTypes: .all, allowRequestOverrides: true), on: app)
            }
        }

        @Test("Test Noops Enabled By Route But Reset")
        func testNoopsEnabledByRouteButReset() async throws {
            try await withCompressionApp { app in
                app.responseCompression(.unset).responseCompression(.enable).responseCompression(.unset).responseCompression(.useDefault).responseCompression(.unset).get("resource") { request in
                    var headers = HTTPFields()
                    headers.contentType = unknownType
                    return try await compressiblePayload.encodeResponse(status: .ok, headers: headers, for: request)
                }

                try await app.server.start()

                try await expectUncompressed(app.http.server.configuration.responseCompression, on: app) /// Default case
                try await expectUncompressed(.forceDisabled, on: app)
                try await expectUncompressed(.disabled, on: app)
                try await expectUncompressed(.enabledForCompressibleTypes, on: app)
                try await expectCompressed(.enabled, on: app)

                try await expectUncompressed(.disabled(allowedTypes: .none, allowRequestOverrides: false), on: app)
                try await expectUncompressed(.disabled(allowedTypes: .compressible, allowRequestOverrides: false), on: app)
                try await expectCompressed(.disabled(allowedTypes: .all, allowRequestOverrides: false), on: app)
                try await expectUncompressed(.disabled(allowedTypes: .none, allowRequestOverrides: true), on: app)
                try await expectUncompressed(.disabled(allowedTypes: .compressible, allowRequestOverrides: true), on: app)
                try await expectCompressed(.disabled(allowedTypes: .all, allowRequestOverrides: true), on: app)

                try await expectCompressed(.enabled(disallowedTypes: .none, allowRequestOverrides: false), on: app)
                try await expectCompressed(.enabled(disallowedTypes: .incompressible, allowRequestOverrides: false), on: app)
                try await expectUncompressed(.enabled(disallowedTypes: .all, allowRequestOverrides: false), on: app)
                try await expectCompressed(.enabled(disallowedTypes: .none, allowRequestOverrides: true), on: app)
                try await expectCompressed(.enabled(disallowedTypes: .incompressible, allowRequestOverrides: true), on: app)
                try await expectUncompressed(.enabled(disallowedTypes: .all, allowRequestOverrides: true), on: app)
            }
        }
    }

    @Suite("Conditional Response Compression Route Tests")
    struct ConditionalResponseCompressionRouteTests {
        func expectResponseCompression(
            middleware: any Middleware,
            responder: any Responder,
            compressionValue: String?,
            on app: Application,
            sourceLocation: SourceLocation = #_sourceLocation
        ) async throws {
            let response = try await middleware.respond(to: Request(application: app, on: app.eventLoopGroup.next()), chainingTo: responder)
            let header = response.headers[values: .xVaporResponseCompression]

            #expect(header == compressionValue.map { $0.components(separatedBy: ", ") }?.map { String($0[...]) } ?? [], sourceLocation: sourceLocation)
        }

        let enabledMiddleware = ResponseCompressionMiddleware(override: .enable)
        let disabledMiddleware = ResponseCompressionMiddleware(override: .disable)
        let defaultMiddleware = ResponseCompressionMiddleware(override: .useDefault)
        let unsetMiddleware = ResponseCompressionMiddleware(override: .unset)

        let forceEnabledMiddleware = ResponseCompressionMiddleware(override: .enable, force: true)
        let forceDisabledMiddleware = ResponseCompressionMiddleware(override: .disable, force: true)
        let forceDefaultMiddleware = ResponseCompressionMiddleware(override: .useDefault, force: true)
        let forceUnsetMiddleware = ResponseCompressionMiddleware(override: .unset, force: true)

        @Test("Test Routing Does Not Prioritize Unset Response")
        func testRoutingDoesNotPrioritizeUnsetResponse() async throws {
            try await withApp { app in
                let unsetResponse = TestResponder { _ in Response() }

                try await expectResponseCompression(middleware: enabledMiddleware, responder: unsetResponse, compressionValue: "enable", on: app)
                try await expectResponseCompression(middleware: disabledMiddleware, responder: unsetResponse, compressionValue: "disable", on: app)
                try await expectResponseCompression(middleware: defaultMiddleware, responder: unsetResponse, compressionValue: "useDefault", on: app)
                try await expectResponseCompression(middleware: unsetMiddleware, responder: unsetResponse, compressionValue: nil, on: app)

                try await expectResponseCompression(middleware: forceEnabledMiddleware, responder: unsetResponse, compressionValue: "enable", on: app)
                try await expectResponseCompression(middleware: forceDisabledMiddleware, responder: unsetResponse, compressionValue: "disable", on: app)
                try await expectResponseCompression(middleware: forceDefaultMiddleware, responder: unsetResponse, compressionValue: "useDefault", on: app)
                try await expectResponseCompression(middleware: forceUnsetMiddleware, responder: unsetResponse, compressionValue: nil, on: app)
            }
        }

        @Test("Test Routing Does Not Prioritize Empty Response")
        func testRoutingDoesNotPrioritizeEmptyResponse() async throws {
            try await withApp { app in
                let emptyResponse = TestResponder { _ in Response(headers: [markerHeader : ""]) }

                try await expectResponseCompression(middleware: enabledMiddleware, responder: emptyResponse, compressionValue: "enable", on: app)
                try await expectResponseCompression(middleware: disabledMiddleware, responder: emptyResponse, compressionValue: "disable", on: app)
                try await expectResponseCompression(middleware: defaultMiddleware, responder: emptyResponse, compressionValue: "useDefault", on: app)
                try await expectResponseCompression(middleware: unsetMiddleware, responder: emptyResponse, compressionValue: nil, on: app)

                try await expectResponseCompression(middleware: forceEnabledMiddleware, responder: emptyResponse, compressionValue: "enable", on: app)
                try await expectResponseCompression(middleware: forceDisabledMiddleware, responder: emptyResponse, compressionValue: "disable", on: app)
                try await expectResponseCompression(middleware: forceDefaultMiddleware, responder: emptyResponse, compressionValue: "useDefault", on: app)
                try await expectResponseCompression(middleware: forceUnsetMiddleware, responder: emptyResponse, compressionValue: nil, on: app)
            }
        }

        @Test("Test Routing Prioritizes Empty Response")
        func testRoutingPrioritizesEnabledResponse() async throws {
            try await withApp { app in
                let enabledResponse = TestResponder { _ in Response(headers: [markerHeader : "enable"]) }

                try await expectResponseCompression(middleware: enabledMiddleware, responder: enabledResponse, compressionValue: "enable", on: app)
                try await expectResponseCompression(middleware: disabledMiddleware, responder: enabledResponse, compressionValue: "enable", on: app)
                try await expectResponseCompression(middleware: defaultMiddleware, responder: enabledResponse, compressionValue: "enable", on: app)
                try await expectResponseCompression(middleware: unsetMiddleware, responder: enabledResponse, compressionValue: "enable", on: app)

                try await expectResponseCompression(middleware: forceEnabledMiddleware, responder: enabledResponse, compressionValue: "enable", on: app)
                try await expectResponseCompression(middleware: forceDisabledMiddleware, responder: enabledResponse, compressionValue: "disable", on: app)
                try await expectResponseCompression(middleware: forceDefaultMiddleware, responder: enabledResponse, compressionValue: "useDefault", on: app)
                try await expectResponseCompression(middleware: forceUnsetMiddleware, responder: enabledResponse, compressionValue: nil, on: app)
            }
        }

        @Test("Test Routing Prioritizes Disabled Response")
        func testRoutingPrioritizesDisabledResponse() async throws {
            try await withApp { app in
                let disabledResponse = TestResponder { _ in Response(headers: [markerHeader : "disable"]) }

                try await expectResponseCompression(middleware: enabledMiddleware, responder: disabledResponse, compressionValue: "disable", on: app)
                try await expectResponseCompression(middleware: disabledMiddleware, responder: disabledResponse, compressionValue: "disable", on: app)
                try await expectResponseCompression(middleware: defaultMiddleware, responder: disabledResponse, compressionValue: "disable", on: app)
                try await expectResponseCompression(middleware: unsetMiddleware, responder: disabledResponse, compressionValue: "disable", on: app)

                try await expectResponseCompression(middleware: forceEnabledMiddleware, responder: disabledResponse, compressionValue: "enable", on: app)
                try await expectResponseCompression(middleware: forceDisabledMiddleware, responder: disabledResponse, compressionValue: "disable", on: app)
                try await expectResponseCompression(middleware: forceDefaultMiddleware, responder: disabledResponse, compressionValue: "useDefault", on: app)
                try await expectResponseCompression(middleware: forceUnsetMiddleware, responder: disabledResponse, compressionValue: nil, on: app)
            }
        }

        @Test("Test Routing Doesn't Profitize Other Response")
        func testRoutingDoesNotPrioritizeOtherResponse() async throws {
            try await withApp { app in
                let otherResponse = TestResponder { _ in Response(headers: [markerHeader : "other"]) }

                try await expectResponseCompression(middleware: enabledMiddleware, responder: otherResponse, compressionValue: "enable", on: app)
                try await expectResponseCompression(middleware: disabledMiddleware, responder: otherResponse, compressionValue: "disable", on: app)
                try await expectResponseCompression(middleware: defaultMiddleware, responder: otherResponse, compressionValue: "useDefault", on: app)
                try await expectResponseCompression(middleware: unsetMiddleware, responder: otherResponse, compressionValue: nil, on: app)

                try await expectResponseCompression(middleware: forceEnabledMiddleware, responder: otherResponse, compressionValue: "enable", on: app)
                try await expectResponseCompression(middleware: forceDisabledMiddleware, responder: otherResponse, compressionValue: "disable", on: app)
                try await expectResponseCompression(middleware: forceDefaultMiddleware, responder: otherResponse, compressionValue: "useDefault", on: app)
                try await expectResponseCompression(middleware: forceUnsetMiddleware, responder: otherResponse, compressionValue: nil, on: app)
            }
        }

        @Test("Test Routing Prioritizes Multiple Response")
        func testRoutingPrioritizesMultipleResponse() async throws {
            try await withApp { app in
                let multipleResponse = TestResponder { _ in Response(headers: [markerHeader : "enable", markerHeader : "disable"]) }

                try await expectResponseCompression(middleware: enabledMiddleware, responder: multipleResponse, compressionValue: "enable, disable", on: app)
                try await expectResponseCompression(middleware: disabledMiddleware, responder: multipleResponse, compressionValue: "enable, disable", on: app)
                try await expectResponseCompression(middleware: defaultMiddleware, responder: multipleResponse, compressionValue: "enable, disable", on: app)
                try await expectResponseCompression(middleware: unsetMiddleware, responder: multipleResponse, compressionValue: "enable, disable", on: app)

                try await expectResponseCompression(middleware: forceEnabledMiddleware, responder: multipleResponse, compressionValue: "enable", on: app)
                try await expectResponseCompression(middleware: forceDisabledMiddleware, responder: multipleResponse, compressionValue: "disable", on: app)
                try await expectResponseCompression(middleware: forceDefaultMiddleware, responder: multipleResponse, compressionValue: "useDefault", on: app)
                try await expectResponseCompression(middleware: forceUnsetMiddleware, responder: multipleResponse, compressionValue: nil, on: app)
            }
        }
    }
}

private let compressiblePayload = #"{"compressed": ["key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value"]}"#

private let unknownType = HTTPMediaType(type: "vapor-test", subType: "unknown")

private struct TestResponder: Responder {
    let transform: @Sendable (_ request: Request) -> Response

    func respond(to request: Request) async throws -> Response {
        transform(request)
    }
}
