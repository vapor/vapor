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
public struct URLEncodedFormEncoder: ContentEncoder, URLQueryEncoder {
    private let configuration: URLEncodedFormCodingConfiguration

    /// Create a new `URLEncodedFormEncoder`.
    ///
    ///        ContentConfiguration.global.use(urlEncoder: URLEncodedFormEncoder(bracketsAsArray: true, flagsAsBool: true, arraySeparator: nil))
    ///
    /// - parameters:
    ///    - configuration: Defines how encoding is done see `URLEncodedFormCodingConfig` for more information
    public init(configuration: URLEncodedFormCodingConfiguration = URLEncodedFormCodingConfiguration(bracketsAsArray: true, flagsAsBool: false, arraySeparator: nil)) {
        self.configuration = configuration
    }
    
    /// `ContentEncoder` conformance.
    public func encode<E>(_ encodable: E, to body: inout ByteBuffer, headers: inout HTTPHeaders) throws
        where E: Encodable
    {
        headers.contentType = .urlEncodedForm
        try body.writeString(self.encode(encodable))
    }
    
    /// `URLContentEncoder` conformance.
    public func encode<E>(_ encodable: E, to url: inout URI) throws where E : Encodable {
        try self.encode(encodable, to: &url, configuration: nil)
    }

    public func encode<E>(_ encodable: E, to url: inout URI, configuration: URLEncodedFormCodingConfiguration? = nil) throws where E : Encodable {
        url.query = try self.encode(encodable, configuration: configuration)
    }

    /// Encodes the supplied `Encodable` object to `Data`.
    ///
    ///     print(user) // User
    ///     let data = try URLEncodedFormEncoder().encode(user)
    ///     print(data) // "name=Vapor&age=3"
    ///
    /// - parameters:
    ///     - encodable: Generic `Encodable` object (`E`) to encode.
    ///     - configuration: Overwrides the  coding config for this encoding call.
    /// - returns: Encoded `Data`
    /// - throws: Any error that may occur while attempting to encode the specified type.
    public func encode<E>(_ encodable: E, configuration: URLEncodedFormCodingConfiguration? = nil) throws -> String
        where E: Encodable
    {
        let decodingConfigToUse = configuration ?? self.configuration

        // This implementation of the encoder does not support encoding to "flags".
        // In order to do so, the children of a `URLEncodedFormData` would need to
        // reference the parent as `SingleValueContainer` does not have a reference
        // to the parent at that time.
        if decodingConfigToUse.flagsAsBool {
            throw Abort(.internalServerError, reason: "URLEncodedFormEncoder does not support flagsAsBool")
        }
        let encoder = _Encoder(codingPath: [], configuration: decodingConfigToUse)
        try encodable.encode(to: encoder)
        let serializer = URLEncodedFormSerializer()
        return try serializer.serialize(encoder.getData())
    }
}

// MARK: Private

private protocol _Container {
    func getData() throws -> URLEncodedFormData
}

private class _Encoder: Encoder {

    var codingPath: [CodingKey]
    private var container: _Container? = nil
    
    func getData() throws -> URLEncodedFormData {
        return try container?.getData() ?? []
    }
    
    var userInfo: [CodingUserInfoKey: Any] {
        return [:]
    }

    private let configuration: URLEncodedFormCodingConfiguration

    init(codingPath: [CodingKey], configuration: URLEncodedFormCodingConfiguration) {
        self.codingPath = codingPath
        self.configuration = configuration
    }

    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key : CodingKey {
        let container = KeyedContainer<Key>(codingPath: codingPath, configuration: configuration)
        self.container = container
        return .init(container)
    }
        
    func unkeyedContainer() -> UnkeyedEncodingContainer {
        let container = UnkeyedContainer(codingPath: codingPath, configuration: configuration)
        self.container = container
        return container
    }
    
    func singleValueContainer() -> SingleValueEncodingContainer {
        let container = SingleValueContainer(codingPath: codingPath, configuration: configuration)
        self.container = container
        return container
    }
    
    private final class KeyedContainer<Key>: KeyedEncodingContainerProtocol, _Container
        where Key: CodingKey
    {
        var codingPath: [CodingKey]
        var internalData: URLEncodedFormData = []
        var childContainers: [String: _Container] = [:]

        func getData() throws -> URLEncodedFormData {
            var result = internalData
            for (key, childContainer) in childContainers {
                result.children[key] = try childContainer.getData()
            }
            return result
        }
        
        private let configuration: URLEncodedFormCodingConfiguration

        init(codingPath: [CodingKey], configuration: URLEncodedFormCodingConfiguration) {
            self.codingPath = codingPath
            self.configuration = configuration
        }
        
        /// See `KeyedEncodingContainerProtocol`
        func encodeNil(forKey key: Key) throws {
            // skip
        }
        
        /// See `KeyedEncodingContainerProtocol`
        func encode<T>(_ value: T, forKey key: Key) throws
            where T : Encodable
        {
            if let convertible = value as? URLQueryFragmentConvertible {
                internalData.children[key.stringValue] = URLEncodedFormData(values: [convertible.urlQueryFragmentValue])
            } else {
                let encoder = _Encoder(codingPath: codingPath + [key], configuration: configuration)
                try value.encode(to: encoder)
                internalData.children[key.stringValue] = try encoder.getData()
            }
        }
        
        /// See `KeyedEncodingContainerProtocol`
        func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey>
            where NestedKey: CodingKey
        {
            let container = KeyedContainer<NestedKey>(codingPath: self.codingPath + [key], configuration: configuration)
            childContainers[key.stringValue] = container
            return .init(container)
        }
        
        /// See `KeyedEncodingContainerProtocol`
        func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
            let container = UnkeyedContainer(codingPath: self.codingPath + [key], configuration: configuration)
            childContainers[key.stringValue] = container
            return container
        }
        
        /// See `KeyedEncodingContainerProtocol`
        func superEncoder() -> Encoder {
            fatalError()
        }
        
        /// See `KeyedEncodingContainerProtocol`
        func superEncoder(forKey key: Key) -> Encoder {
            fatalError()
        }
    }
    
    /// Private `UnkeyedEncodingContainer`.
    private final class UnkeyedContainer: UnkeyedEncodingContainer, _Container {
        var codingPath: [CodingKey]
        var count: Int = 0
        var internalData: URLEncodedFormData = []
        var childContainers: [Int: _Container] = [:]
        private let configuration: URLEncodedFormCodingConfiguration

        func getData() throws -> URLEncodedFormData {
            var result = internalData
            for (key, childContainer) in childContainers {
                result.children[String(key)] = try childContainer.getData()
            }
            if let arraySeparator = configuration.arraySeparator {
                var valuesToImplode = result.values
                result.values = []
                if configuration.bracketsAsArray,
                    let emptyStringChild = internalData.children[""] {
                    valuesToImplode = valuesToImplode + emptyStringChild.values
                    result.children[""]?.values = []
                }
                let implodedValue = try valuesToImplode.map({ (value: URLQueryFragment) -> String in
                    return try value.asUrlEncoded()
                }).joined(separator: String(arraySeparator))
                result.values = [.urlEncoded(implodedValue)]
            }
            return result
        }
        
        init(codingPath: [CodingKey], configuration: URLEncodedFormCodingConfiguration) {
            self.codingPath = codingPath
            self.configuration = configuration
        }
        
        func encodeNil() throws {
            // skip
        }
        
        func encode<T>(_ value: T) throws where T: Encodable {
            defer { count += 1 }
            if let convertible = value as? URLQueryFragmentConvertible {
                let value = convertible.urlQueryFragmentValue
                if configuration.bracketsAsArray {
                    var emptyStringChild = internalData.children[""] ?? []
                    emptyStringChild.values.append(value)
                    internalData.children[""] = emptyStringChild
                } else {
                    internalData.values.append(value)
                }
            } else {
                let encoder = _Encoder(codingPath: codingPath, configuration: configuration)
                try value.encode(to: encoder)
                let childData = try encoder.getData()
                if childData.hasOnlyValues {
                    if configuration.bracketsAsArray {
                        var emptyStringChild = internalData.children[""] ?? []
                        emptyStringChild.values.append(contentsOf: childData.values)
                        internalData.children[""] = emptyStringChild
                    } else {
                        internalData.values.append(contentsOf: childData.values)
                    }
                } else {
                    internalData.children[count.description] = try encoder.getData()
                }
            }
        }
        
        /// See UnkeyedEncodingContainer.nestedContainer
        func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey>
            where NestedKey: CodingKey
        {
            defer { count += 1 }
            let container = KeyedContainer<NestedKey>(codingPath: self.codingPath, configuration: configuration)
            childContainers[count] = container
            return .init(container)
        }
        
        /// See UnkeyedEncodingContainer.nestedUnkeyedContainer
        func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
            defer { count += 1 }
            let container = UnkeyedContainer(codingPath: self.codingPath, configuration: configuration)
            childContainers[count] = container
            return container
        }
        
        /// See UnkeyedEncodingContainer.superEncoder
        func superEncoder() -> Encoder {
            fatalError()
        }
    }

    /// Private `SingleValueEncodingContainer`.
    private final class SingleValueContainer: SingleValueEncodingContainer, _Container {
        /// See `SingleValueEncodingContainer`
        var codingPath: [CodingKey]
        
        func getData() throws -> URLEncodedFormData {
            return data
        }

        /// The data being encoded
        var data: URLEncodedFormData = []
        
        private let configuration: URLEncodedFormCodingConfiguration

        /// Creates a new single value encoder
        init(codingPath: [CodingKey], configuration: URLEncodedFormCodingConfiguration) {
            self.codingPath = codingPath
            self.configuration = configuration
        }
        
        /// See `SingleValueEncodingContainer`
        func encodeNil() throws {
            // skip
        }
        
        /// See `SingleValueEncodingContainer`
        func encode<T>(_ value: T) throws where T: Encodable {
            if let convertible = value as? URLQueryFragmentConvertible {
                data.values.append(convertible.urlQueryFragmentValue)
            } else {
                let encoder = _Encoder(codingPath: self.codingPath, configuration: configuration)
                try value.encode(to: encoder)
                data = try encoder.getData()
            }
        }
    }
}

private extension EncodingError {
    static func invalidValue(_ value: Any, at path: [CodingKey]) -> EncodingError {
        let pathString = path.map { $0.stringValue }.joined(separator: ".")
        let context = EncodingError.Context(
            codingPath: path,
            debugDescription: "Invalid value at '\(pathString)': \(value)"
        )
        return Swift.EncodingError.invalidValue(value, context)
    }
}
