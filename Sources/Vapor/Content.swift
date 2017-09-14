import Core
import Foundation
import HTTP

/// A type capable of encoding an `Encodable` to a `Body`
public protocol ContentEncoder {
    /// The supported `MediaType`
    static var type: MediaType { get }
    
    /// Encodes to the `MediaType` statelessly
    static func encodeBody<E: Encodable>(from entity: E) throws -> Body
}

/// A type capable of decoding an `Encodable` from a `Body`
public protocol ContentDecoder {
    static var type: MediaType { get }
    
    /// Decodes from the `MediaType` statelessly
    static func decode<D: Decodable>(_ entity: D.Type, from body: Body) throws -> D
}

/// `Foundation.JSONEncoder` as JSON ContentEncoder
extension JSONEncoder: ContentEncoder {
    /// The supported `MediaType`
    public static var type: MediaType {
        return .json
    }
    
    /// Encodes to the `MediaType` statelessly
    public static func encodeBody<E>(from entity: E) throws -> Body where E : Encodable {
        return Body(try JSONEncoder().encode(entity))
    }
}

/// `Foundation.JSONDecoder` as JSON ContentDecoder
extension JSONDecoder: ContentDecoder {
    /// The supported `MediaType`
    public static var type: MediaType {
        return .json
    }
    
    /// Decodes from the `MediaType` statelessly
    public static func decode<D>(_ entity: D.Type, from body: Body) throws -> D where D : Decodable {
        return try JSONDecoder().decode(D.self, from: body.data)
    }
}

/// A class that keeps track of all `ContentEncoder`s and `ContentDecoder`s
public final class ContentCoders {
    /// An array of MediaType + ContentEncoders
    public var encoders: [(MediaType, ContentEncoder.Type)]
    
    /// An array of MediaType + ContentDecoders
    public var decoders: [(MediaType, ContentDecoder.Type)]
    
    /// The "default" set of encoders
    public static let `default` = ContentCoders()
    
    /// Creates a new, default set of Vapor supported encoders and decoders
    public init() {
        self.encoders = [
            (.json, JSONEncoder.self)
        ]
        
        self.decoders = [
            (.json, JSONDecoder.self)
        ]
    }
}
