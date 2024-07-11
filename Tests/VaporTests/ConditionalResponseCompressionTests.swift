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
