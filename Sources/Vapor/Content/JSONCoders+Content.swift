import Foundation
import NIOCore
import NIOFoundationCompat
import NIOHTTP1

#if canImport(Darwin)
extension JSONEncoder: @retroactive @unchecked Sendable {} // JSONEncoder Sendable conformance is not available before macOS 13.0/iOS 16.0/watchOS 9.0/tvOS 16.0
extension JSONDecoder: @retroactive @unchecked Sendable {} // JSONDecoder Sendable conformance is not available before macOS 13.0/iOS 16.0/watchOS 9.0/tvOS 16.0
#endif

extension JSONEncoder: ContentEncoder {
    public func encode<E>(_ encodable: E, to body: inout ByteBuffer, headers: inout HTTPHeaders) throws
        where E: Encodable
    {
        try self.encode(encodable, to: &body, headers: &headers, userInfo: [:])
    }
    
    public func encode<E>(_ encodable: E, to body: inout ByteBuffer, headers: inout HTTPHeaders, userInfo: [CodingUserInfoKey: Sendable]) throws
        where E: Encodable
    {
        headers.contentType = .json
        
        if !userInfo.isEmpty { // Changing a coder's userInfo is a thread-unsafe mutation, operate on a copy
            try body.writeBytes(JSONEncoder.custom(
                dates: self.dateEncodingStrategy,
                data: self.dataEncodingStrategy,
                keys: self.keyEncodingStrategy,
                format: self.outputFormatting,
                floats: self.nonConformingFloatEncodingStrategy,
                userInfo: self.userInfo.merging(userInfo) { $1 }
            ).encode(encodable))
        } else {
            try body.writeBytes(self.encode(encodable))
        }
    }
}

extension JSONDecoder: ContentDecoder {
    public func decode<D>(_ decodable: D.Type, from body: ByteBuffer, headers: HTTPHeaders) throws -> D
        where D: Decodable
    {
        try self.decode(D.self, from: body, headers: headers, userInfo: [:])
    }
    
    public func decode<D>(_ decodable: D.Type, from body: ByteBuffer, headers: HTTPHeaders, userInfo: [CodingUserInfoKey: Sendable]) throws -> D
        where D: Decodable
    {
        let data = body.getData(at: body.readerIndex, length: body.readableBytes) ?? Data()
        
        if !userInfo.isEmpty {
            let actualDecoder = JSONDecoder() // Changing a coder's userInfo is a thread-unsafe mutation, operate on a copy
            actualDecoder.dateDecodingStrategy = self.dateDecodingStrategy
            actualDecoder.dataDecodingStrategy = self.dataDecodingStrategy
            actualDecoder.nonConformingFloatDecodingStrategy = self.nonConformingFloatDecodingStrategy
            actualDecoder.keyDecodingStrategy = self.keyDecodingStrategy
            #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
            if #available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *) {
                actualDecoder.allowsJSON5 = self.allowsJSON5
                actualDecoder.assumesTopLevelDictionary = self.assumesTopLevelDictionary
            }
            #endif
            actualDecoder.userInfo = self.userInfo.merging(userInfo) { $1 }
            return try actualDecoder.decode(D.self, from: data)
        } else {
            return try self.decode(D.self, from: data)
        }
    }
}
