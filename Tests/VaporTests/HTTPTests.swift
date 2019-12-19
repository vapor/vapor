@testable import Vapor
import NIOTestUtils
import XCTest
import NIO
import NIOHTTP1

final class HTTPTests: XCTestCase {
    func testRequestDecoder() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        
        let decoder = HTTPServerRequestDecoder(application: app, maxBodySize: 1 >> 16)
        let channel = EmbeddedChannel(handler: decoder)
        
        var buffer = ByteBufferAllocator().buffer(capacity: 0)
        buffer.writeString("hello")
        
        try channel.writeInbound(HTTPServerRequestPart.head(.init(
            version: .init(major: 1, minor: 1),
            method: .POST,
            uri: "/foo",
            headers: ["foo": "bar"]
        )))
        
        try XCTAssertNil(channel.readInbound(as: Request.self))
        
        try channel.writeInbound(HTTPServerRequestPart.body(buffer))
        try XCTAssertNil(channel.readInbound(as: Request.self))
        
        try channel.writeInbound(HTTPServerRequestPart.body(buffer))
        let req = try channel.readInbound(as: Request.self)!

        try channel.writeInbound(HTTPServerRequestPart.end(nil))
        
        let data = try req.body.collect().wait()
        XCTAssertEqual(data?.readableBytes, 10)
    }
}
