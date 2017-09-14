import Core
import Foundation
import HTTP

public protocol ContentEncoder {
    static var type: MediaType { get }
    static func encodeBody<E: Encodable>(from entity: E) throws -> Body
}

public protocol ContentDecoder {
    static var type: MediaType { get }
    static func decode<D: Decodable>(_ entity: D.Type, from body: Body) throws -> D
}

extension JSONEncoder: ContentEncoder {
    public static var type: MediaType {
        return .json
    }
    
    public static func encodeBody<E>(from entity: E) throws -> Body where E : Encodable {
        return Body(try JSONEncoder().encode(entity))
    }
}

extension JSONDecoder: ContentDecoder {
    public static var type: MediaType {
        return .json
    }
    
    public static func decode<D>(_ entity: D.Type, from body: Body) throws -> D where D : Decodable {
        return try JSONDecoder().decode(D.self, from: body.data)
    }
}

public final class ContentCoders {
    public var encoders: [(MediaType, ContentEncoder.Type)]
    public var decoders: [(MediaType, ContentDecoder.Type)]
    
    public static let `default` = ContentCoders()
    
    public init() {
        self.encoders = [
            (.json, JSONEncoder.self)
        ]
        
        self.decoders = [
            (.json, JSONDecoder.self)
        ]
    }
}
