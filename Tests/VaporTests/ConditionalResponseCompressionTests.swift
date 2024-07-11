#if !canImport(Darwin)
@preconcurrency import Dispatch
#endif
import Foundation
import Vapor
import XCTest
import AsyncHTTPClient
import NIOCore
import NIOPosix
import NIOConcurrencyHelpers
import NIOHTTP1
import NIOSSL
import Atomics


let markerHeader = HTTPHeaders.Name.xVaporResponseCompression.description

final class ConditionalResponseCompressionParsingTests: XCTestCase, @unchecked Sendable {
    func testEncodingEnable() {
        var headers = HTTPHeaders()
        headers.responseCompression = .enable
        XCTAssertEqual(headers, [markerHeader : "enable"])
    }
    
    func testEncodingDisable() {
        var headers = HTTPHeaders()
        headers.responseCompression = .disable
        XCTAssertEqual(headers, [markerHeader : "disable"])
    }
    
    func testEncodingUseDefault() {
        var headers = HTTPHeaders()
        headers.responseCompression = .useDefault
        XCTAssertEqual(headers, [markerHeader : "useDefault"])
    }
    
    func testEncodingUnset() {
        var headers = HTTPHeaders()
        headers.responseCompression = .unset
        XCTAssertEqual(headers, [:])
    }
    
    func testUpdating() {
        var headers = HTTPHeaders()
        headers.responseCompression = .enable
        XCTAssertEqual(headers, [markerHeader : "enable"])
        headers.responseCompression = .disable
        XCTAssertEqual(headers, [markerHeader : "disable"])
        headers.responseCompression = .unset
        XCTAssertEqual(headers, [:])
        headers.add(name: markerHeader, value: "enable")
        headers.add(name: markerHeader, value: "disable")
        XCTAssertEqual(headers, [markerHeader : "enable", markerHeader : "disable"])
        headers.responseCompression = .disable
        XCTAssertEqual(headers, [markerHeader : "disable"])
    }
    
    func testDecodingUnset() {
        let headers: HTTPHeaders = [:]
        XCTAssertEqual(headers.responseCompression, .unset)
    }
    
    func testDecodingEnabled() {
        let headers: HTTPHeaders = [markerHeader : "enable"]
        XCTAssertEqual(headers.responseCompression, .enable)
    }
    
    func testDecodingDisabled() {
        let headers: HTTPHeaders = [markerHeader : "disable"]
        XCTAssertEqual(headers.responseCompression, .disable)
    }
    
    func testDecodingUseDefault() {
        let headers: HTTPHeaders = [markerHeader : "useDefault"]
        XCTAssertEqual(headers.responseCompression, .useDefault)
    }
    
    func testDecodingLiteralUnset() {
        let headers: HTTPHeaders = [markerHeader : "unset"]
        XCTAssertEqual(headers.responseCompression, .unset)
    }
    
    func testDecodingOther() {
        let headers: HTTPHeaders = [markerHeader : "other"]
        XCTAssertEqual(headers.responseCompression, .unset)
    }
    
    func testDecodingMultipleValid() {
        let headers: HTTPHeaders = [markerHeader : "enable", markerHeader : "disable"]
        XCTAssertEqual(headers.responseCompression, .disable)
    }
    
    func testDecodingMultipleFirstInvalid() {
        let headers: HTTPHeaders = [markerHeader : "other", markerHeader : "enable"]
        XCTAssertEqual(headers.responseCompression, .enable)
    }
    
    func testDecodingMultipleLastInvalid() {
        let headers: HTTPHeaders = [markerHeader : "enable", markerHeader : "other"]
        XCTAssertEqual(headers.responseCompression, .unset)
    }
}


private let compressiblePayload = #"{"compressed": ["key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value", "key": "value"]}"#

private let unknownType = HTTPMediaType(type: "vapor-test", subType: "unknown")


final class ConditionalResponseCompressionServerTests: XCTestCase, @unchecked Sendable {
    var app: Application!
    
    func assertCompressed(
        _ configuration: HTTPServer.Configuration.CompressionConfiguration,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        XCTAssertNotNil(app.http.server.shared.localAddress)
        guard let localAddress = app.http.server.shared.localAddress,
              let port = localAddress.port else {
            XCTFail("couldn't get ip/port from \(app.http.server.shared.localAddress.debugDescription)")
            return
        }
        
        app.http.server.configuration.responseCompression = configuration
        
        let response = try await app.client.get("http://localhost:\(port)/resource") { request in
            request.headers.replaceOrAdd(name: .acceptEncoding, value: "gzip")
        }
        XCTAssertEqual(response.headers.first(name: .contentEncoding), "gzip", file: file, line: line)
        XCTAssertNotEqual(response.headers.first(name: .contentLength), "\(compressiblePayload.count)", file: file, line: line)
        XCTAssertEqual(response.body?.string, compressiblePayload, file: file, line: line)
    }
    
    func assertUncompressed(
        _ configuration: HTTPServer.Configuration.CompressionConfiguration,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        XCTAssertNotNil(app.http.server.shared.localAddress)
        guard let localAddress = app.http.server.shared.localAddress,
              let port = localAddress.port else {
            XCTFail("couldn't get ip/port from \(app.http.server.shared.localAddress.debugDescription)")
            return
        }
        
        app.http.server.configuration.responseCompression = configuration
        
        let response = try await app.client.get("http://localhost:\(port)/resource") { request in
            request.headers.replaceOrAdd(name: .acceptEncoding, value: "gzip")
        }
        XCTAssertNotEqual(response.headers.first(name: .contentEncoding), "gzip", file: file, line: line)
        XCTAssertEqual(response.headers.first(name: .contentLength), "\(compressiblePayload.count)", file: file, line: line)
        XCTAssertEqual(response.body?.string, compressiblePayload, file: file, line: line)
    }
    
    override func setUp() async throws {
        let test = Environment(name: "testing", arguments: ["vapor"])
        app = try await Application.make(test)
        app.http.server.configuration.hostname = "127.0.0.1"
        app.http.server.configuration.port = 0
        
        app.http.server.configuration.supportVersions = [.one]
        
        /// Make sure the client doesn't keep the server open by re-using the connection.
        app.http.client.configuration.maximumUsesPerConnection = 1
        app.http.client.configuration.decompression = .enabled(limit: .none)
    }
    
    override func tearDown() async throws {
        try await app.asyncShutdown()
    }
    
    func testAutoDetectedType() async throws {
        app.get("resource") { _ in compressiblePayload }
        
        try app.server.start()
        defer { app.server.shutdown() }
        
        try await assertUncompressed(app.http.server.configuration.responseCompression) /// Default case
        try await assertUncompressed(.forceDisabled)
        try await assertUncompressed(.disabled)
        try await assertCompressed(.enabledForCompressibleTypes)
        try await assertCompressed(.enabled)
        
        try await assertUncompressed(.disabled(allowedTypes: .none, allowRequestOverrides: false))
        try await assertCompressed(.disabled(allowedTypes: .compressible, allowRequestOverrides: false))
        try await assertCompressed(.disabled(allowedTypes: .all, allowRequestOverrides: false))
        try await assertUncompressed(.disabled(allowedTypes: .none, allowRequestOverrides: true))
        try await assertCompressed(.disabled(allowedTypes: .compressible, allowRequestOverrides: true))
        try await assertCompressed(.disabled(allowedTypes: .all, allowRequestOverrides: true))
        
        try await assertCompressed(.enabled(disallowedTypes: .none, allowRequestOverrides: false))
        try await assertCompressed(.enabled(disallowedTypes: .incompressible, allowRequestOverrides: false))
        try await assertUncompressed(.enabled(disallowedTypes: .all, allowRequestOverrides: false))
        try await assertCompressed(.enabled(disallowedTypes: .none, allowRequestOverrides: true))
        try await assertCompressed(.enabled(disallowedTypes: .incompressible, allowRequestOverrides: true))
        try await assertUncompressed(.enabled(disallowedTypes: .all, allowRequestOverrides: true))
    }
    
    func testUnknownType() async throws {
        app.get("resource") { request in
            var headers = HTTPHeaders()
            headers.contentType = unknownType /// Not explicitely marked as compressible or not.
            return compressiblePayload.encodeResponse(status: .ok, headers: headers, for: request)
        }
        
        try app.server.start()
        defer { app.server.shutdown() }
        
        try await assertUncompressed(app.http.server.configuration.responseCompression) /// Default case
        try await assertUncompressed(.forceDisabled)
        try await assertUncompressed(.disabled)
        try await assertUncompressed(.enabledForCompressibleTypes)
        try await assertCompressed(.enabled)
        
        try await assertUncompressed(.disabled(allowedTypes: .none, allowRequestOverrides: false))
        try await assertUncompressed(.disabled(allowedTypes: .compressible, allowRequestOverrides: false))
        try await assertCompressed(.disabled(allowedTypes: .all, allowRequestOverrides: false))
        try await assertUncompressed(.disabled(allowedTypes: .none, allowRequestOverrides: true))
        try await assertUncompressed(.disabled(allowedTypes: .compressible, allowRequestOverrides: true))
        try await assertCompressed(.disabled(allowedTypes: .all, allowRequestOverrides: true))
        
        try await assertCompressed(.enabled(disallowedTypes: .none, allowRequestOverrides: false))
        try await assertCompressed(.enabled(disallowedTypes: .incompressible, allowRequestOverrides: false))
        try await assertUncompressed(.enabled(disallowedTypes: .all, allowRequestOverrides: false))
        try await assertCompressed(.enabled(disallowedTypes: .none, allowRequestOverrides: true))
        try await assertCompressed(.enabled(disallowedTypes: .incompressible, allowRequestOverrides: true))
        try await assertUncompressed(.enabled(disallowedTypes: .all, allowRequestOverrides: true))
    }
    
    func testImage() async throws {
        app.get("resource") { request in
            var headers = HTTPHeaders()
            headers.contentType = .png /// PNGs are explicitely called out as incompressible.
            return compressiblePayload.encodeResponse(status: .ok, headers: headers, for: request)
        }
        
        try app.server.start()
        defer { app.server.shutdown() }
        
        try await assertUncompressed(app.http.server.configuration.responseCompression) /// Default case
        try await assertUncompressed(.forceDisabled)
        try await assertUncompressed(.disabled)
        try await assertUncompressed(.enabledForCompressibleTypes)
        try await assertUncompressed(.enabled)
        
        try await assertUncompressed(.disabled(allowedTypes: .none, allowRequestOverrides: false))
        try await assertUncompressed(.disabled(allowedTypes: .compressible, allowRequestOverrides: false))
        try await assertCompressed(.disabled(allowedTypes: .all, allowRequestOverrides: false))
        try await assertUncompressed(.disabled(allowedTypes: .none, allowRequestOverrides: true))
        try await assertUncompressed(.disabled(allowedTypes: .compressible, allowRequestOverrides: true))
        try await assertCompressed(.disabled(allowedTypes: .all, allowRequestOverrides: true))
        
        try await assertCompressed(.enabled(disallowedTypes: .none, allowRequestOverrides: false))
        try await assertUncompressed(.enabled(disallowedTypes: .incompressible, allowRequestOverrides: false))
        try await assertUncompressed(.enabled(disallowedTypes: .all, allowRequestOverrides: false))
        try await assertCompressed(.enabled(disallowedTypes: .none, allowRequestOverrides: true))
        try await assertUncompressed(.enabled(disallowedTypes: .incompressible, allowRequestOverrides: true))
        try await assertUncompressed(.enabled(disallowedTypes: .all, allowRequestOverrides: true))
    }
    
    func testVideo() async throws {
        app.get("resource") { request in
            var headers = HTTPHeaders()
            headers.contentType = .mpeg /// Videos are explicitely called out as incompressible, but as a class.
            return compressiblePayload.encodeResponse(status: .ok, headers: headers, for: request)
        }
        
        try app.server.start()
        defer { app.server.shutdown() }
        
        try await assertUncompressed(app.http.server.configuration.responseCompression) /// Default case
        try await assertUncompressed(.forceDisabled)
        try await assertUncompressed(.disabled)
        try await assertUncompressed(.enabledForCompressibleTypes)
        try await assertUncompressed(.enabled)
        
        try await assertUncompressed(.disabled(allowedTypes: .none, allowRequestOverrides: false))
        try await assertUncompressed(.disabled(allowedTypes: .compressible, allowRequestOverrides: false))
        try await assertCompressed(.disabled(allowedTypes: .all, allowRequestOverrides: false))
        try await assertUncompressed(.disabled(allowedTypes: .none, allowRequestOverrides: true))
        try await assertUncompressed(.disabled(allowedTypes: .compressible, allowRequestOverrides: true))
        try await assertCompressed(.disabled(allowedTypes: .all, allowRequestOverrides: true))
        
        try await assertCompressed(.enabled(disallowedTypes: .none, allowRequestOverrides: false))
        try await assertUncompressed(.enabled(disallowedTypes: .incompressible, allowRequestOverrides: false))
        try await assertUncompressed(.enabled(disallowedTypes: .all, allowRequestOverrides: false))
        try await assertCompressed(.enabled(disallowedTypes: .none, allowRequestOverrides: true))
        try await assertUncompressed(.enabled(disallowedTypes: .incompressible, allowRequestOverrides: true))
        try await assertUncompressed(.enabled(disallowedTypes: .all, allowRequestOverrides: true))
    }
    
    func testText() async throws {
        app.get("resource") { request in
            var headers = HTTPHeaders()
            headers.contentType = .plainText /// Text types are explicitely called out as compressible, but as a class.
            return compressiblePayload.encodeResponse(status: .ok, headers: headers, for: request)
        }
        
        try app.server.start()
        defer { app.server.shutdown() }
        
        try await assertUncompressed(app.http.server.configuration.responseCompression) /// Default case
        try await assertUncompressed(.forceDisabled)
        try await assertUncompressed(.disabled)
        try await assertCompressed(.enabledForCompressibleTypes)
        try await assertCompressed(.enabled)
        
        try await assertUncompressed(.disabled(allowedTypes: .none, allowRequestOverrides: false))
        try await assertCompressed(.disabled(allowedTypes: .compressible, allowRequestOverrides: false))
        try await assertCompressed(.disabled(allowedTypes: .all, allowRequestOverrides: false))
        try await assertUncompressed(.disabled(allowedTypes: .none, allowRequestOverrides: true))
        try await assertCompressed(.disabled(allowedTypes: .compressible, allowRequestOverrides: true))
        try await assertCompressed(.disabled(allowedTypes: .all, allowRequestOverrides: true))
        
        try await assertCompressed(.enabled(disallowedTypes: .none, allowRequestOverrides: false))
        try await assertCompressed(.enabled(disallowedTypes: .incompressible, allowRequestOverrides: false))
        try await assertUncompressed(.enabled(disallowedTypes: .all, allowRequestOverrides: false))
        try await assertCompressed(.enabled(disallowedTypes: .none, allowRequestOverrides: true))
        try await assertCompressed(.enabled(disallowedTypes: .incompressible, allowRequestOverrides: true))
        try await assertUncompressed(.enabled(disallowedTypes: .all, allowRequestOverrides: true))
    }
    
    func testEnabledByResponse() async throws {
        app.get("resource") { request in
            var headers = HTTPHeaders()
            headers.contentType = unknownType
            headers.responseCompression = .enable
            return compressiblePayload.encodeResponse(status: .ok, headers: headers, for: request)
        }
        
        try app.server.start()
        defer { app.server.shutdown() }
        
        try await assertCompressed(app.http.server.configuration.responseCompression) /// Default case
        try await assertUncompressed(.forceDisabled)
        try await assertCompressed(.disabled)
        try await assertCompressed(.enabledForCompressibleTypes)
        try await assertCompressed(.enabled)
        
        try await assertUncompressed(.disabled(allowedTypes: .none, allowRequestOverrides: false))
        try await assertUncompressed(.disabled(allowedTypes: .compressible, allowRequestOverrides: false))
        try await assertCompressed(.disabled(allowedTypes: .all, allowRequestOverrides: false))
        try await assertCompressed(.disabled(allowedTypes: .none, allowRequestOverrides: true))
        try await assertCompressed(.disabled(allowedTypes: .compressible, allowRequestOverrides: true))
        try await assertCompressed(.disabled(allowedTypes: .all, allowRequestOverrides: true))
        
        try await assertCompressed(.enabled(disallowedTypes: .none, allowRequestOverrides: false))
        try await assertCompressed(.enabled(disallowedTypes: .incompressible, allowRequestOverrides: false))
        try await assertCompressed(.enabled(disallowedTypes: .all, allowRequestOverrides: false))
        try await assertCompressed(.enabled(disallowedTypes: .none, allowRequestOverrides: true))
        try await assertCompressed(.enabled(disallowedTypes: .incompressible, allowRequestOverrides: true))
        try await assertCompressed(.enabled(disallowedTypes: .all, allowRequestOverrides: true))
    }
    
    func testDisabledByResponse() async throws {
        app.get("resource") { request in
            var headers = HTTPHeaders()
            headers.contentType = unknownType
            headers.responseCompression = .disable
            return compressiblePayload.encodeResponse(status: .ok, headers: headers, for: request)
        }
        
        try app.server.start()
        defer { app.server.shutdown() }
        
        try await assertUncompressed(app.http.server.configuration.responseCompression) /// Default case
        try await assertUncompressed(.forceDisabled)
        try await assertUncompressed(.disabled)
        try await assertUncompressed(.enabledForCompressibleTypes)
        try await assertUncompressed(.enabled)
        
        try await assertUncompressed(.disabled(allowedTypes: .none, allowRequestOverrides: false))
        try await assertUncompressed(.disabled(allowedTypes: .compressible, allowRequestOverrides: false))
        try await assertCompressed(.disabled(allowedTypes: .all, allowRequestOverrides: false))
        try await assertUncompressed(.disabled(allowedTypes: .none, allowRequestOverrides: true))
        try await assertUncompressed(.disabled(allowedTypes: .compressible, allowRequestOverrides: true))
        try await assertUncompressed(.disabled(allowedTypes: .all, allowRequestOverrides: true))
        
        try await assertUncompressed(.enabled(disallowedTypes: .none, allowRequestOverrides: false))
        try await assertUncompressed(.enabled(disallowedTypes: .incompressible, allowRequestOverrides: false))
        try await assertUncompressed(.enabled(disallowedTypes: .all, allowRequestOverrides: false))
        try await assertUncompressed(.enabled(disallowedTypes: .none, allowRequestOverrides: true))
        try await assertUncompressed(.enabled(disallowedTypes: .incompressible, allowRequestOverrides: true))
        try await assertUncompressed(.enabled(disallowedTypes: .all, allowRequestOverrides: true))
    }
}
