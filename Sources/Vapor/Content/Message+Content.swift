import Foundation

public struct ContentContainer {
    weak var message: AnyMessage?
}

extension ContentContainer {
    /// Serializes the supplied content to this message.
    /// Uses the Content's default media type if none is supplied.
    public func encode<C: Content>(_ content: C) throws {
        let coders = try message!.make(ContentConfig.self, for: ContentContainer.self)
        let encoder = try coders.requireEncoder(for: C.defaultMediaType)
        message!._http.body = try HTTPBody(encoder.encode(content))
        message!._http.mediaType = C.defaultMediaType
    }

    /// Serializes the supplied content to this message.
    /// Uses the Content's default media type if none is supplied.
    public func encode<E: Encodable>(_ encodable: E, as mediaType: MediaType) throws {
        let coders = try message!.make(ContentConfig.self, for: ContentContainer.self)
        let encoder = try coders.requireEncoder(for: mediaType)
        message!._http.body = try HTTPBody(encoder.encode(encodable))
        message!._http.mediaType = mediaType
    }
    
    /// Parses the supplied content from the mesage.
    public func decode<D: Decodable>(_ content: D.Type) throws -> D {
        let coders = try message!.make(ContentConfig.self, for: ContentContainer.self)
        guard let mediaType = message!._http.mediaType else {
            throw "no media type"
        }
        guard let data = message!._http.body.data else {
            throw "no body data"
        }
        let encoder = try coders.requireDecoder(for: mediaType)
        return try encoder.decode(D.self, from: data)
    }
}

extension QueryContainer {
    /// Parses the supplied content from the mesage.
    public func decode<D: Decodable>(_ decodable: D.Type) throws -> D {
        let coders = try container.make(ContentConfig.self, for: QueryContainer.self)
        let encoder = try coders.requireDecoder(for: .urlEncodedForm)
        return try encoder.decode(D.self, from: Data(query.utf8))
    }
}

/// MARK: AnyMessage

/// FIXME: can we clean this up?

protocol AnyMessage: Container {
    var _http: HTTPMessage { get set }
}

extension Request: AnyMessage {
    var _http: HTTPMessage {
        get { return http }
        set { http = newValue as! HTTPRequest }
    }
}

extension Response: AnyMessage {
    var _http: HTTPMessage {
        get { return http }
        set { http = newValue as! HTTPResponse }
    }
}
