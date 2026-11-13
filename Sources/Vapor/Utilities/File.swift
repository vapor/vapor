#if canImport(FoundationEssentials)
public import FoundationEssentials
#else
public import Foundation
#endif

/// Represents a single file.
public struct File: Codable, Equatable, Sendable {
    /// Name of the file, including extension.
    public var filename: String

    /// The file's data.
    public var data: Data

    /// Associated `MediaType` for this file, preferring the explicitly set value, falling back to the file extension.
    public var contentType: HTTPMediaType? {
        get { _contentType ?? self.extension.flatMap { HTTPMediaType.fileExtension($0.lowercased()) } }
        set { _contentType = newValue }
    }

    private var _contentType: HTTPMediaType?

    /// The file extension, if it has one.
    public var `extension`: String? {
        let parts = self.filename.split(separator: ".")
        if parts.count > 1 {
            return parts.last.map(String.init)
        } else {
            return nil
        }
    }

    /// Creates a new `File`.
    ///
    ///     let file = File(data: "hello", filename: "foo.txt")
    ///
    /// - parameters:
    ///     - data: The file's contents.
    ///     - filename: The name of the file, not including path.
    public init(data: String, filename: String, contentType: HTTPMediaType? = nil) {
        self.init(data: Data(data.utf8), filename: filename, contentType: contentType)
    }

    /// Creates a new `File`.
    ///
    ///     let file = File(data: [0x48, 0x65, 0x6c, 0x6c, 0x6f], filename: "foo.txt")
    ///
    /// - parameters:
    ///     - data: The file's contents.
    ///     - filename: The name of the file, not including path.
    public init(data: Data, filename: String, contentType: HTTPMediaType? = nil) {
        self.data = data
        self.filename = filename
        self.contentType = contentType
    }

    enum CodingKeys: String, CodingKey {
        case data, filename, contentType
    }

    /// `Decodable` conformance.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let data = try container.decode(Data.self, forKey: .data)
        let filename = try container.decode(String.self, forKey: .filename)
        self.init(data: data, filename: filename)
    }

    /// `Encodable` conformance.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(data, forKey: .data)
        try container.encode(self.filename, forKey: .filename)
        if let contentType {
            try container.encode(contentType.serialize(), forKey: .contentType)
        }
    }
}
