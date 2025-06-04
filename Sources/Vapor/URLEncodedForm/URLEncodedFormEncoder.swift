import Foundation
import HTTPTypes
import NIOCore

/// Encodes `Encodable` instances to `application/x-www-form-urlencoded` data.
///
///     print(user) /// User
///     let data = try URLEncodedFormEncoder().encode(user)
///     print(data) /// Data
///
/// URL-encoded forms are commonly used by websites to send form data via POST requests. This encoding is relatively
/// efficient for small amounts of data but must be percent-encoded.  `multipart/form-data` is more efficient for sending
/// large data blobs like files.
///
/// See [Mozilla's](https://developer.mozilla.org/en-US/docs/Web/HTTP/Methods/POST) docs for more information about
/// url-encoded forms.
/// NOTE: This implementation of the encoder does not support encoding booleans to "flags".
public struct URLEncodedFormEncoder: ContentEncoder, URLQueryEncoder, Sendable {
    /// Used to capture URLForm Coding Configuration used for encoding.
    public struct Configuration: Sendable {
        /// Supported array encodings.
        public enum ArrayEncoding: Sendable {
            /// Arrays are serialized as separate values with bracket suffixed keys.
            /// For example, `foo = [1,2,3]` would be serialized as `foo[]=1&foo[]=2&foo[]=3`.
            case bracket
            /// Arrays are serialized as a single value with character-separated items.
            /// For example, `foo = [1,2,3]` would be serialized as `foo=1,2,3`.
            case separator(Character)
            /// Arrays are serialized as separate values.
            /// For example, `foo = [1,2,3]` would be serialized as `foo=1&foo=2&foo=3`.
            case values
        }

        /// Supported date formats
        public enum DateEncodingStrategy: Sendable {
            /// Seconds since 1 January 1970 00:00:00 UTC (Unix Timestamp)
            case secondsSince1970
            /// ISO 8601 formatted date
            case iso8601
            /// Using custom callback
            case custom(@Sendable (Date, any Encoder) throws -> Void)
        }
        /// Specified array encoding.
        public var arrayEncoding: ArrayEncoding
        public var dateEncodingStrategy: DateEncodingStrategy
        public var userInfo: [CodingUserInfoKey: any Sendable]

        /// Creates a new `Configuration`.
        ///
        ///  - parameters:
        ///     - arrayEncoding: Specified array encoding. Defaults to `.bracket`.
        ///     - dateFormat: Format to encode date format too. Defaults to `secondsSince1970`
        public init(
            arrayEncoding: ArrayEncoding = .bracket,
            dateEncodingStrategy: DateEncodingStrategy = .secondsSince1970,
            userInfo: [CodingUserInfoKey: any Sendable] = [:]
        ) {
            self.arrayEncoding = arrayEncoding
            self.dateEncodingStrategy = dateEncodingStrategy
            self.userInfo = userInfo
        }
    }

    private let configuration: Configuration

    /// Create a new `URLEncodedFormEncoder`.
    ///
    ///      var contentConfiguration = ContentConfiguration.default()
    ///      contentConfiguration.use(urlEncoder: URLEncodedFormEncoder())
    ///
    /// - Parameters:
    ///  - configuration: Defines how encoding is done; see ``URLEncodedFormEncoder/Configuration`` for more information
    public init(configuration: Configuration = .init()) {
        self.configuration = configuration
    }
    
    // See `ContentEncoder.encode(_:to:headers:)`.
    public func encode(_ encodable: some Encodable, to body: inout ByteBuffer, headers: inout HTTPFields) throws {
        try self.encode(encodable, to: &body, headers: &headers, userInfo: [:])
    }

    // See `ContentEncoder.encode(_:to:headers:userInfo:)`.
    public func encode(_ encodable: some Encodable, to body: inout ByteBuffer, headers: inout HTTPFields, userInfo: [CodingUserInfoKey: any Sendable]) throws {
        headers.contentType = .urlEncodedForm
        try body.writeString(self.encode(encodable, userInfo: userInfo))
    }
    
    // See `URLQueryEncoder.encode(_:to:)`.
    public func encode(_ encodable: some Encodable, to url: inout URI) throws {
        try self.encode(encodable, to: &url, userInfo: [:])
    }
    
    // See `URLQueryEncoder.encode(_:to:userInfo:)`.
    public func encode(_ encodable: some Encodable, to url: inout URI, userInfo: [CodingUserInfoKey: any Sendable]) throws {
        url.query = try self.encode(encodable, userInfo: userInfo)
    }

    /// Encodes the supplied ``Encodable`` object to ``String``.
    ///
    ///     print(user) // User
    ///     let data = try URLEncodedFormEncoder().encode(user)
    ///     print(data) // "name=Vapor&age=3"
    ///
    /// - Parameters:
    ///   - encodable: Generic ``Encodable`` object (``E``) to encode.
    ///   - userInfo: Overrides the default coder user info.
    /// - Returns: Encoded ``String``
    /// - Throws: Any error that may occur while attempting to encode the specified type.
    public func encode(_ encodable: some Encodable, userInfo: [CodingUserInfoKey: any Sendable] = [:]) throws -> String {
        var configuration = self.configuration  // Changing a coder's userInfo is a thread-unsafe mutation, operate on a copy
        if !userInfo.isEmpty {
            configuration.userInfo.merge(userInfo) { $1 }
        }
        let encoder = _Encoder(codingPath: [], configuration: configuration)
        try encodable.encode(to: encoder)
        let serializer = URLEncodedFormSerializer()
        return try serializer.serialize(encoder.getData())
    }
}

// MARK: Private

private protocol _Container {
    func getData() throws -> URLEncodedFormData
}

private class _Encoder: Encoder, _Container {
    var codingPath: [any CodingKey]
    var userInfo: [CodingUserInfoKey: Any] { self.configuration.userInfo }

    private var container: (any _Container)? = nil
    private let configuration: URLEncodedFormEncoder.Configuration

    func getData() throws -> URLEncodedFormData { try self.container?.getData() ?? [] }

    init(codingPath: [any CodingKey], configuration: URLEncodedFormEncoder.Configuration) {
        self.codingPath = codingPath
        self.configuration = configuration
    }

    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key : CodingKey {
        let container = KeyedContainer<Key>(codingPath: codingPath, configuration: configuration)
        self.container = container
        return .init(container)
    }
        
    func unkeyedContainer() -> any UnkeyedEncodingContainer {
        let container = UnkeyedContainer(codingPath: codingPath, configuration: configuration)
        self.container = container
        return container
    }
    
    func singleValueContainer() -> any SingleValueEncodingContainer {
        let container = SingleValueContainer(codingPath: codingPath, configuration: configuration)
        self.container = container
        return container
    }
    
    private final class KeyedContainer<Key>: KeyedEncodingContainerProtocol, _Container
        where Key: CodingKey
    {
        var codingPath: [any CodingKey]
        var internalData: URLEncodedFormData = []
        var childContainers: [String: any _Container] = [:]

        func getData() throws -> URLEncodedFormData {
            var result = self.internalData
            for (key, childContainer) in self.childContainers {
                result.children[key] = try childContainer.getData()
            }
            return result
        }
        
        private let configuration: URLEncodedFormEncoder.Configuration

        init(
            codingPath: [any CodingKey],
            configuration: URLEncodedFormEncoder.Configuration
        ) {
            self.codingPath = codingPath
            self.configuration = configuration
        }
        
        // See `KeyedEncodingContainerProtocol.encodeNil(forKey:)`.
        func encodeNil(forKey key: Key) throws {
            // skip
        }
        
        // See `KeyedEncodingContainerProtocol.encode(_:forKey:)`.
        func encode(_ value: some Encodable, forKey key: Key) throws {
            if let date = value as? Date {
                self.internalData.children[key.stringValue] = try self.configuration.encodeDate(date, codingPath: self.codingPath, forKey: key)
            } else if let convertible = value as? any URLQueryFragmentConvertible {
                self.internalData.children[key.stringValue] = URLEncodedFormData(values: [convertible.urlQueryFragmentValue])
            } else {
                let encoder = _Encoder(codingPath: self.codingPath + [key], configuration: self.configuration)
                try value.encode(to: encoder)
                self.internalData.children[key.stringValue] = try encoder.getData()
            }
        }
        
        // See `KeyedEncodingContainerProtocol.nestedContainer(keyedBy:forKey:)`.
        func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey>
            where NestedKey: CodingKey
        {
            let container = KeyedContainer<NestedKey>(
                codingPath: self.codingPath + [key],
                configuration: self.configuration
            )
            self.childContainers[key.stringValue] = container
            return .init(container)
        }
        
        // See `KeyedEncodingContainerProtocol.nestedUnkeyedContainer(_:forKey:)`.
        func nestedUnkeyedContainer(forKey key: Key) -> any UnkeyedEncodingContainer {
            let container = UnkeyedContainer(
                codingPath: self.codingPath + [key],
                configuration: self.configuration
            )
            self.childContainers[key.stringValue] = container
            return container
        }
        
        // See `KeyedEncodingContainerProtocol.superEncoder()`.
        func superEncoder() -> any Encoder {
            let encoder = _Encoder(codingPath: self.codingPath + ["super".codingKey], configuration: self.configuration)
            self.childContainers["super"] = encoder
            return encoder
        }
        
        // See `KeyedEncodingContainerProtocol.superEncoder(forKey:)`.
        func superEncoder(forKey key: Key) -> any Encoder {
            let encoder = _Encoder(codingPath: self.codingPath + [key], configuration: self.configuration)
            self.childContainers[key.stringValue] = encoder
            return encoder
        }
    }
    
    /// Private `UnkeyedEncodingContainer`.
    private final class UnkeyedContainer: UnkeyedEncodingContainer, _Container {
        var codingPath: [any CodingKey]
        var count: Int = 0
        var internalData: URLEncodedFormData = []
        var childContainers: [Int: any _Container] = [:]
        private let configuration: URLEncodedFormEncoder.Configuration

        func getData() throws -> URLEncodedFormData {
            var result = self.internalData
            for (key, childContainer) in self.childContainers {
                result.children[String(key)] = try childContainer.getData()
            }
            switch self.configuration.arrayEncoding {
            case .separator(let arraySeparator):
                var valuesToImplode = result.values
                result.values = []
                if case .bracket = self.configuration.arrayEncoding, let emptyStringChild = self.internalData.children[""] {
                    valuesToImplode = valuesToImplode + emptyStringChild.values
                    result.children[""]?.values = []
                }
                let implodedValue = try valuesToImplode.map { try $0.asUrlEncoded() }.joined(separator: String(arraySeparator))
                result.values = [.urlEncoded(implodedValue)]
            case .bracket, .values:
                break
            }
            return result
        }
        
        init(codingPath: [any CodingKey], configuration: URLEncodedFormEncoder.Configuration) {
            self.codingPath = codingPath
            self.configuration = configuration
        }
        
        func encodeNil() throws {
            // skip
        }
        
        func encode(_ value: some Encodable) throws {
            if let date = value as? Date {
                let encodedDate = try self.configuration.encodeDate(date, codingPath: self.codingPath, forKey: self.count.codingKey)
                switch self.configuration.arrayEncoding {
                case .bracket:
                    var emptyStringChild = self.internalData.children[""] ?? []
                    emptyStringChild.values.append(contentsOf: encodedDate.values)
                    self.internalData.children[""] = emptyStringChild
                case .separator, .values:
                    self.internalData.values.append(contentsOf: encodedDate.values)
                }
            } else if let convertible = value as? any URLQueryFragmentConvertible {
                let value = convertible.urlQueryFragmentValue
                switch self.configuration.arrayEncoding {
                case .bracket:
                    var emptyStringChild = self.internalData.children[""] ?? []
                    emptyStringChild.values.append(value)
                    self.internalData.children[""] = emptyStringChild
                case .separator, .values:
                    self.internalData.values.append(value)
                }
            } else {
                let encoder = _Encoder(codingPath: self.codingPath + [self.count.codingKey], configuration: configuration)
                try value.encode(to: encoder)
                let childData = try encoder.getData()
                if childData.hasOnlyValues {
                    switch self.configuration.arrayEncoding {
                    case .bracket:
                        var emptyStringChild = self.internalData.children[""] ?? []
                        emptyStringChild.values.append(contentsOf: childData.values)
                        self.internalData.children[""] = emptyStringChild
                    case .separator, .values:
                        self.internalData.values.append(contentsOf: childData.values)
                    }
                } else {
                    self.internalData.children[self.count.description] = try encoder.getData()
                }
            }
            self.count += 1 // we don't want to do this if anything earlier threw an error
        }
        
        // See `UnkeyedEncodingContainer.nestedContainer(keyedBy:)`.
        func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey>
            where NestedKey: CodingKey
        {
            defer { self.count += 1 }
            let container = KeyedContainer<NestedKey>(
                codingPath: self.codingPath + [self.count.codingKey],
                configuration: self.configuration
            )
            self.childContainers[self.count] = container
            return .init(container)
        }
        
        // See `UnkeyedEncodingContainer.nestedUnkeyedContainer()`.
        func nestedUnkeyedContainer() -> any UnkeyedEncodingContainer {
            defer { self.count += 1 }
            let container = UnkeyedContainer(
                codingPath: self.codingPath + [self.count.codingKey],
                configuration: self.configuration
            )
            self.childContainers[self.count] = container
            return container
        }
        
        // See `UnkeyedEncodingContainer.superEncoder()`.
        func superEncoder() -> any Encoder {
            defer { self.count += 1 }
            let encoder = _Encoder(codingPath: self.codingPath + [self.count.codingKey], configuration: self.configuration)
            self.childContainers[self.count] = encoder
            return encoder
        }
    }

    /// Private `SingleValueEncodingContainer`.
    private final class SingleValueContainer: SingleValueEncodingContainer, _Container {
        // See `SingleValueEncodingContainer.codingPath`.
        var codingPath: [any CodingKey]

        func getData() throws -> URLEncodedFormData { self.data }

        /// The data being encoded
        var data: URLEncodedFormData = []
        
        private let configuration: URLEncodedFormEncoder.Configuration

        /// Creates a new single value encoder
        init(
            codingPath: [any CodingKey],
            configuration: URLEncodedFormEncoder.Configuration
        ) {
            self.codingPath = codingPath
            self.configuration = configuration
        }
        
        // See `SingleValueEncodingContainer.encodeNil()`.
        func encodeNil() throws {
            // skip
        }
        
        // See `SingleValueEncodingContainer.encode(_:)`.
        func encode(_ value: some Encodable) throws {
            if let date = value as? Date {
                self.data = try self.configuration.encodeDate(date, codingPath: self.codingPath, forKey: nil)
            } else if let convertible = value as? any URLQueryFragmentConvertible {
                self.data.values.append(convertible.urlQueryFragmentValue)
            } else {
                let encoder = _Encoder(codingPath: self.codingPath, configuration: self.configuration)
                try value.encode(to: encoder)
                self.data = try encoder.getData()
            }
        }
    }
}

private extension URLEncodedFormEncoder.Configuration {
    func encodeDate(_ date: Date, codingPath: [any CodingKey], forKey key: (any CodingKey)?) throws -> URLEncodedFormData {
        switch dateEncodingStrategy {
        case .secondsSince1970:
            return URLEncodedFormData(values: [date.urlQueryFragmentValue])
        case .iso8601:
            return URLEncodedFormData(values: [
                ISO8601DateFormatter().string(from: date).urlQueryFragmentValue
            ])
        case .custom(let callback):
            let newCodingPath = codingPath + (key.map { [$0] } ?? [])
            let encoder = _Encoder(codingPath: newCodingPath, configuration: self)
            try callback(date, encoder)
            return try encoder.getData()
        }
    }
}

private extension EncodingError {
    static func invalidValue(_ value: Any, at path: [any CodingKey]) -> EncodingError {
        let context = EncodingError.Context(
            codingPath: path,
            debugDescription: "Invalid value at '\(path.dotPath)': \(value)"
        )
        return Swift.EncodingError.invalidValue(value, context)
    }
}
