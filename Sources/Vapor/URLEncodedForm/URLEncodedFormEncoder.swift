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
public struct URLEncodedFormEncoder: ContentEncoder, URLQueryEncoder {

    private let codingConfig: URLEncodedFormCodingConfig

    /// Create a new `URLEncodedFormEncoder`.
    public init(with codingConfig: URLEncodedFormCodingConfig = URLEncodedFormCodingConfig(bracketsAsArray: true, flagsAsBool: false, arraySeparator: nil)) {
        self.codingConfig = codingConfig
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
        try self.encode(encodable, to: &url, codingConfig: nil)
    }

    public func encode<E>(_ encodable: E, to url: inout URI, codingConfig: URLEncodedFormCodingConfig? = nil) throws where E : Encodable {
        url.query = try self.encode(encodable)
    }

    /// Encodes the supplied `Encodable` object to `Data`.
    ///
    ///     print(user) // User
    ///     let data = try URLEncodedFormEncoder().encode(user)
    ///     print(data) // "name=Vapor&age=3"
    ///
    /// - parameters:
    ///     - encodable: Generic `Encodable` object (`E`) to encode.
    /// - returns: Encoded `Data`
    /// - throws: Any error that may occur while attempting to encode the specified type.
    public func encode<E>(_ encodable: E, codingConfig: URLEncodedFormCodingConfig? = nil) throws -> String
        where E: Encodable
    {
        let decodingConfigToUse = codingConfig ?? self.codingConfig
        if decodingConfigToUse.flagsAsBool {
            throw Abort(.internalServerError, reason: "URLEncodedFormEncoder does not support flagsAsBool")
        }
        let encoder = _Encoder(codingPath: [], codingConfig: decodingConfigToUse)
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

    private let codingConfig: URLEncodedFormCodingConfig

    init(codingPath: [CodingKey], codingConfig: URLEncodedFormCodingConfig) {
        self.codingPath = codingPath
        self.codingConfig = codingConfig
    }

    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key : CodingKey {
        let container = KeyedContainer<Key>(codingPath: codingPath, codingConfig: codingConfig)
        self.container = container
        return .init(container)
    }
        
    func unkeyedContainer() -> UnkeyedEncodingContainer {
        let container = UnkeyedContainer(codingPath: codingPath, codingConfig: codingConfig)
        self.container = container
        return container
    }
    
    func singleValueContainer() -> SingleValueEncodingContainer {
        let container = SingleValueContainer(codingPath: codingPath, codingConfig: codingConfig)
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
        
        private let codingConfig: URLEncodedFormCodingConfig

        init(codingPath: [CodingKey], codingConfig: URLEncodedFormCodingConfig) {
            self.codingPath = codingPath
            self.codingConfig = codingConfig
        }
        
        /// See `KeyedEncodingContainerProtocol`
        func encodeNil(forKey key: Key) throws {
            // skip
        }
        
        /// See `KeyedEncodingContainerProtocol`
        func encode<T>(_ value: T, forKey key: Key) throws
            where T : Encodable
        {
            if let convertible = value as? URLEncodedFormFieldConvertible {
                internalData.children[key.stringValue] = URLEncodedFormData(stringLiteral: convertible.urlEncodedFormValue)
            } else {
                let encoder = _Encoder(codingPath: codingPath + [key], codingConfig: codingConfig)
                try value.encode(to: encoder)
                internalData.children[key.stringValue] = try encoder.getData()
            }
        }
        
        /// See `KeyedEncodingContainerProtocol`
        func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey>
            where NestedKey: CodingKey
        {
            let container = KeyedContainer<NestedKey>(codingPath: self.codingPath + [key], codingConfig: codingConfig)
            childContainers[key.stringValue] = container
            return .init(container)
        }
        
        /// See `KeyedEncodingContainerProtocol`
        func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
            let container = UnkeyedContainer(codingPath: self.codingPath + [key], codingConfig: codingConfig)
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
        private let codingConfig: URLEncodedFormCodingConfig

        func getData() throws -> URLEncodedFormData {
            var result = internalData
            for (key, childContainer) in childContainers {
                result.children[String(key)] = try childContainer.getData()
            }
            if let arraySeparator = codingConfig.arraySeparator {
                var valuesToImplode = result.values
                result.values = []
                if codingConfig.bracketsAsArray,
                    let emptyStringChild = internalData.children[""] {
                    valuesToImplode = valuesToImplode + emptyStringChild.values
                    result.children[""]?.values = []
                }
                let implodedValue = try valuesToImplode.map({ (value: URLEncodedFormPercentEncodedFragment) -> String in
                    return try value.encoded()
                }).joined(separator: String(arraySeparator))
                result.values = [.encoded(implodedValue)]
            }
            return result
        }
        
        init(codingPath: [CodingKey], codingConfig: URLEncodedFormCodingConfig) {
            self.codingPath = codingPath
            self.codingConfig = codingConfig
        }
        
        func encodeNil() throws {
            // skip
        }
        
        func encode<T>(_ value: T) throws where T: Encodable {
            defer { count += 1 }
            if let convertible = value as? URLEncodedFormFieldConvertible {
                let value = convertible.urlEncodedFormValue
                if codingConfig.bracketsAsArray {
                    var emptyStringChild = internalData.children[""] ?? []
                    emptyStringChild.values.append(.decoded(value))
                    internalData.children[""] = emptyStringChild
                } else {
                    internalData.values.append(.decoded(value))
                }
            } else {
                let encoder = _Encoder(codingPath: codingPath, codingConfig: codingConfig)
                try value.encode(to: encoder)
                let childData = try encoder.getData()
                if childData.hasOnlyValues {
                    if codingConfig.bracketsAsArray {
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
            let container = KeyedContainer<NestedKey>(codingPath: self.codingPath, codingConfig: codingConfig)
            childContainers[count] = container
            return .init(container)
        }
        
        /// See UnkeyedEncodingContainer.nestedUnkeyedContainer
        func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
            defer { count += 1 }
            let container = UnkeyedContainer(codingPath: self.codingPath, codingConfig: codingConfig)
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
        
        private let codingConfig: URLEncodedFormCodingConfig

        /// Creates a new single value encoder
        init(codingPath: [CodingKey], codingConfig: URLEncodedFormCodingConfig) {
            self.codingPath = codingPath
            self.codingConfig = codingConfig
        }
        
        /// See `SingleValueEncodingContainer`
        func encodeNil() throws {
            // skip
        }
        
        /// See `SingleValueEncodingContainer`
        func encode<T>(_ value: T) throws where T: Encodable {
            if let convertible = value as? URLEncodedFormFieldConvertible {
                data.values.append(.decoded(convertible.urlEncodedFormValue))
            } else {
                let encoder = _Encoder(codingPath: self.codingPath, codingConfig: codingConfig)
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
