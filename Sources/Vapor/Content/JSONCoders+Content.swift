import Foundation
import NIOCore
import HTTPTypes

extension JSONEncoder: ContentEncoder {
    public func encode<E>(_ encodable: E, to body: inout ByteBuffer, headers: inout HTTPFields) throws
        where E: Encodable
    {
        try self.encode(encodable, to: &body, headers: &headers, userInfo: [:])
    }
    
    public func encode<E>(_ encodable: E, to body: inout ByteBuffer, headers: inout HTTPFields, userInfo: [CodingUserInfoKey: any Sendable]) throws
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
    public func decode<D>(_ decodable: D.Type, from body: ByteBuffer, headers: HTTPFields) throws -> D
        where D: Decodable
    {
        try self.decode(D.self, from: body, headers: headers, userInfo: [:])
    }
    
    public func decode<D>(_ decodable: D.Type, from body: ByteBuffer, headers: HTTPFields, userInfo: [CodingUserInfoKey: any Sendable]) throws -> D
        where D: Decodable
    {
        let data = body.getData(at: body.readerIndex, length: body.readableBytes) ?? Data()
        
        if !userInfo.isEmpty {
            let actualDecoder = JSONDecoder() // Changing a coder's userInfo is a thread-unsafe mutation, operate on a copy
            actualDecoder.dateDecodingStrategy = self.dateDecodingStrategy
            actualDecoder.dataDecodingStrategy = self.dataDecodingStrategy
            actualDecoder.nonConformingFloatDecodingStrategy = self.nonConformingFloatDecodingStrategy
            actualDecoder.keyDecodingStrategy = self.keyDecodingStrategy
            actualDecoder.allowsJSON5 = self.allowsJSON5
            actualDecoder.assumesTopLevelDictionary = self.assumesTopLevelDictionary
            actualDecoder.userInfo = self.userInfo.merging(userInfo) { $1 }
            return try actualDecoder.decode(D.self, from: data)
        } else {
            return try self.decode(D.self, from: data)
        }
    }
}
