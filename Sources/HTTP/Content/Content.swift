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
    public func content<C: ContentEncodable>(_ encodable: C) throws {
        try encodable.encodeContent(to: self)
    }

    public func content<C: ContentDecodable>(_ decodable: C.Type = C.self) throws -> C? {
        return try decodable.decodeContent(from: self)
    }

    public func requireContent<C: ContentDecodable>(_ decodable: C.Type = C.self) throws -> C {
        guard let content = try self.content(C.self) else {
            throw Error.contentRequired(C.self)
        }

        return content
    }
}
