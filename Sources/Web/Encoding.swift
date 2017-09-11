import Foundation
import Async
import Bits

/// Encodes buffers
public protocol ContentEncoder {
    // Encodes the buffer
    func encode(_ buffer: ByteBuffer) throws -> ByteBuffer
    
    init(headers: Headers) throws
}

extension ContentEncoder {
    /// Encodes data to an encoded data blob
    public func encode(_ data: Data) throws -> Data {
        return try data.withUnsafeBytes { (pointer: BytesPointer) -> Data in
            let buffer = ByteBuffer(start: pointer, count: data.count)
            return Data(try self.encode(buffer))
        }
    }
}

/// Decodes buffers
public protocol ContentDecoder {
    // Decodes the buffer
    func decode(_ buffer: ByteBuffer) throws -> ByteBuffer
    
    init(headers: Headers) throws
}

extension ContentDecoder {
    /// Encodes data to a decoded data blob
    public func decode(_ data: Data) throws -> Data {
        return try data.withUnsafeBytes { (pointer: BytesPointer) -> Data in
            let buffer = ByteBuffer(start: pointer, count: data.count)
            return Data(try self.decode(buffer))
        }
    }
}

/// An encoding registery
public enum DataEncoding {
    public typealias ContentEncoderBuilder = ((Headers) throws -> (ContentEncoder))
    public typealias ContentDecoderBuilder = ((Headers) throws -> (ContentDecoder))
    
    /// Keeps track of all encoding types and their encoder and decoder
    public static var registery: [String: (encoder: ContentEncoderBuilder, decoder: ContentDecoderBuilder)] = [
        "binary": (BinaryContentCoder.init, BinaryContentCoder.init)
    ]
    
    public static let binary = BinaryContentCoder()
}

public final class BinaryContentCoder: ContentEncoder, ContentDecoder {
    public func encode(_ buffer: ByteBuffer) throws -> ByteBuffer {
        return buffer
    }
    
    public func decode(_ buffer: ByteBuffer) throws -> ByteBuffer {
        return buffer
    }
    
    public init() {}
    public init(headers: Headers) throws {}
}
