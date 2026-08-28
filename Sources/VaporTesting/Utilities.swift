#warning("We should remove this when we don't need ByteBuffer")
public import NIOCore

extension ByteBuffer {
    public var string: String {
        .init(decoding: self.readableBytesView, as: UTF8.self)
    }
}

#if canImport(FoundationEssentials)
public import FoundationEssentials
#else
public import Foundation
#endif

extension Data {
    public var string: String {
        .init(decoding: self, as: UTF8.self)
    }
}

public import Vapor
import HTTPTypes

extension Response.Body {
    public func requireString(max: Int? = nil) async throws -> String {
        guard let string = try await self.string(max: max) else {
            throw Abort(.unprocessableContent)
        }
        return string
    }
}
