import Core
import Foundation
import HTTP
import Service
import Routing

extension Request {
    public func decode<D: Decodable>(as: D.Type) throws -> D {
        guard let media = self.mediaType else {
            throw Error.unknownMediaType()
        }
        
        for (type, decoder) in ContentCoders.default.decoders where type == media {
            return try decoder.decode(D.self, from: self.body)
        }
        
        throw Error.unknownMediaType()
    }
}

extension ResponseRepresentable where Self: Encodable {
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
