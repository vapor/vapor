//import Async
//import Bits
//
///// Any type that can provide a transfer encoding or decoding stream
//public protocol TransferCoder {
//    var mapStream: MapStream<ByteBuffer, ByteBuffer> { get }
//}
//
///// A combination of an encoder and decoder of the same type
//public final class TransferEncoding {
//    /// A function that can create a new encoder or decoder
//    public typealias Factory = () -> TransferCoder
//    
//    /// The encoding factory
//    private let encoderFactory: Factory
//    
//    /// The decoding factory
//    private let decoderFactory: Factory
//    
//    /// Creates a new encoder for this encoding
//    public func encoder() -> TransferCoder {
//        return encoderFactory()
//    }
//    
//    /// Creates a new decoder for this encoding
//    public func decoder() -> TransferCoder {
//        return decoderFactory()
//    }
//    
//    /// Creates a new transfer encoding
//    public init(encoder: @escaping Factory, decoder: @escaping Factory) {
//        self.encoderFactory = encoder
//        self.decoderFactory = decoder
//    }
//}

