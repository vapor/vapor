import Foundation

/// ContentEncodable & ContentDecodable.
public typealias ContentCodable = ContentEncodable & ContentDecodable

/// Types conforming to this protocol can be used
/// to extract content from HTTP message bodies.
public protocol ContentDecodable {
    /// Parses the body data into content.
    static func decodeContent(from message: Message) throws -> Self?
}

/// Types conforming to this protocol can be used
/// to extract content from HTTP message bodies.
public protocol ContentEncodable {
    /// Serializes the content into body data.
    func encodeContent(to message: Message) throws
}

// MARK: Message

extension Message {
    /// The mediatype for this message
    public var mediaType: MediaType? {
        get {
            guard let contentType = headers[.contentType] else {
                return nil
            }

            return MediaType(string: contentType)
        }
        set {
            headers[.contentType] = newValue?.description
        }
    }
}

extension Message {
    /// Encodes this message from the provided `ContentEncodable` instance
    public func encode<C: ContentEncodable>(from encodable: C) throws {
        try encodable.encodeContent(to: self)
    }

    /// Decodes this message into the provided `ContentDecodable` type
    public func decode<C: ContentDecodable>(to decodable: C.Type = C.self) throws -> C? {
        return try decodable.decodeContent(from: self)
    }

    /// Extracts this message as the provided `ContentDecodable`
    ///
    /// Throws an error if decoding returned `nil`
    public func requireContent<C: ContentDecodable>(as decodable: C.Type = C.self) throws -> C {
        guard let content = try self.decode(to: C.self) else {
            throw Error.contentRequired(C.self)
        }

        return content
    }
}
