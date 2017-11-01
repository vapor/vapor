import Foundation
import HTTP
import Bits

/// Encodes buffers
public protocol TransferEncoder {
    // Encodes the buffer
    func encode(_ buffer: ByteBuffer) throws -> ByteBuffer
    
    init(headers: Headers) throws
}

extension TransferEncoder {
    /// Encodes data to an encoded data blob
    public func encode(_ data: Data) throws -> Data {
        return try data.withUnsafeBytes { (pointer: BytesPointer) -> Data in
            let buffer = ByteBuffer(start: pointer, count: data.count)
            return Data(try self.encode(buffer))
        }
    }
}

/// Decodes buffers
public protocol TransferDecoder {
    // Decodes the buffer
    func decode(_ buffer: ByteBuffer) throws -> ByteBuffer
    
    init(headers: Headers) throws
}

extension TransferDecoder {
    /// Encodes data to a decoded data blob
    public func decode(_ data: Data) throws -> Data {
        return try data.withUnsafeBytes { (pointer: BytesPointer) -> Data in
            let buffer = ByteBuffer(start: pointer, count: data.count)
            return Data(try self.decode(buffer))
        }
    }
}

/// An encoding registery
public enum TransferEncoding {
    public typealias TransferEncoderBuilder = ((Headers) throws -> (TransferEncoder))
    public typealias TransferDecoderBuilder = ((Headers) throws -> (TransferDecoder))
    
    /// Keeps track of all encoding types and their encoder and decoder
    public static var registery: [String: (encoder: TransferEncoderBuilder, decoder: TransferDecoderBuilder)] = [
        "binary": (BinaryTransferCoder.init, BinaryTransferCoder.init)
    ]
    
    public static let binary = BinaryTransferCoder()
}

/// No encoding
public final class BinaryTransferCoder: TransferEncoder, TransferDecoder {
    /// Returns the input
    public func encode(_ buffer: ByteBuffer) throws -> ByteBuffer {
        return buffer
    }
    
    /// Returns the input
    public func decode(_ buffer: ByteBuffer) throws -> ByteBuffer {
        return buffer
    }
    
    /// Helper initializer, since Headers aren't used
    public init() {}
    
    public init(headers: Headers) throws {}
}
