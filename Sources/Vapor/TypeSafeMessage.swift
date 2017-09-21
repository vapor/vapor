import Core
import Foundation
import HTTP
import Service
import Routing

extension Message {
    /// Decodes the `Body` of a `Message` using the `MediaType`'s associated `ContentDecoder`
    public func decode<D: Decodable>(as: D.Type) throws -> D {
        guard let media = self.mediaType else {
            throw Error.unknownMediaType()
        }
        
        for (type, decoder) in ContentCoders.default.decoders where type == media {
            return try decoder.makeBody(self.body, from: D.self)
        }
        
        throw Error.unknownMediaType()
    }
    
    /// Encodes an `Encodable` using the `MediaType`'s associated `ContentEncoder` to the `Message`'s body
    public func encode<E: Encodable>(_ entity: E, as media: MediaType = .json) throws {
        for (type, encoder) in ContentCoders.default.encoders where type == media {
            self.body = try encoder.encodeBody(from: entity)
            return
        }
        
        throw Error.unknownMediaType()
    }
}

/// Provides a default implementation for `Encodable & ResponseRepresnetables` types
extension ResponseRepresentable where Self: Encodable {
    /// Encodes this `Response` using the default `MediaType` encoding.
    ///
    /// Uses the `Accept` header to determine the correct `MediaType`
    public func makeResponse(for request: Request) throws -> Response {
        // TODO: Multiple accepted types
        // https://en.wikipedia.org/wiki/Content_negotiation
        guard let accept = request.headers[.accept], let media = MediaType(string: accept) else {
            throw Error.unknownMediaType()
        }
        
        for (type, encoder) in ContentCoders.default.encoders where type == media {
            let body = try encoder.encodeBody(from: self)
            
            return Response(headers: [
                .contentType: media.description
            ], body: body)
        }
        
        throw Error.unknownMediaType()
    }
}

