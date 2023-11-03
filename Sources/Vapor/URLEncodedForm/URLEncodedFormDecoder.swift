import NIOCore
import Foundation
import NIOHTTP1

private typealias Configuration = URLEncodedFormDecoder.Configuration

/// Decodes instances of `Decodable` types from `application/x-www-form-urlencoded` `Data`.
///
///     print(data) // "name=Vapor&age=3"
///     let user = try URLEncodedFormDecoder().decode(User.self, from: data)
///     print(user) // User
///
/// URL-encoded forms are commonly used by websites to send form data via POST requests. This encoding is relatively
/// efficient for small amounts of data but must be percent-encoded.  `multipart/form-data` is more efficient for sending
/// large data blobs like files.
///
/// See [Mozilla's](https://developer.mozilla.org/en-US/docs/Web/HTTP/Methods/POST) docs for more information about
/// url-encoded forms.
public struct URLEncodedFormDecoder: ContentDecoder, URLQueryDecoder {
    /// Used to capture URLForm Coding Configuration used for decoding
    public struct Configuration {
        /// Supported date formats
        public enum DateDecodingStrategy {
            /// Seconds since 1 January 1970 00:00:00 UTC (Unix Timestamp)
            case secondsSince1970
            /// ISO 8601 formatted date
            case iso8601
            /// Using custom callback
            case custom((Decoder) throws -> Date)
        }

        /// The strategy to use for automatically changing the value of keys before decoding.
        public enum KeyDecodingStrategy : Sendable {
            /// Use the keys specified by each type. This is the default strategy.
            case useDefaultKeys

            /// Convert from "snake_case_keys" to "camelCaseKeys" before attempting to match a key with the one specified by each type.
            ///
            /// The conversion to upper case uses `Locale.system`, also known as the ICU "root" locale. This means the result is consistent regardless of the current user's locale and language preferences.
            ///
            /// Converting from snake case to camel case:
            /// 1. Capitalizes the word starting after each `_`
            /// 2. Removes all `_`
            /// 3. Preserves starting and ending `_` (as these are often used to indicate private variables or other metadata).
            /// For example, `one_two_three` becomes `oneTwoThree`. `_one_two_three_` becomes `_oneTwoThree_`.
            ///
            /// - Note: Using a key decoding strategy has a nominal performance cost, as each string key has to be inspected for the `_` character.
            case convertFromSnakeCase

            /// Provide a custom conversion from the key in the encoded queries to the keys specified by the decoded types.
            /// The full path to the current decoding position is provided for context (in case you need to locate this key within the payload). The returned key is used in place of the last component in the coding path before decoding.
            /// If the result of the conversion is a duplicate key, then only one value will be present in the container for the type to decode from.
            case custom((_ codingPath: [CodingKey]) -> CodingKey)

            fileprivate static func _convertFromSnakeCase(_ stringKey: String) -> String {
                guard !stringKey.isEmpty else { return stringKey }

                // Find the first non-underscore character
                guard let firstNonUnderscore = stringKey.firstIndex(where: { $0 != "_" }) else {
                    // Reached the end without finding an _
                    return stringKey
                }

                // Find the last non-underscore character
                var lastNonUnderscore = stringKey.index(before: stringKey.endIndex)
                while lastNonUnderscore > firstNonUnderscore && stringKey[lastNonUnderscore] == "_" {
                    stringKey.formIndex(before: &lastNonUnderscore)
                }

                let keyRange = firstNonUnderscore...lastNonUnderscore
                let leadingUnderscoreRange = stringKey.startIndex..<firstNonUnderscore
                let trailingUnderscoreRange = stringKey.index(after: lastNonUnderscore)..<stringKey.endIndex

                let components = stringKey[keyRange].split(separator: "_")
                let joinedString: String
                if components.count == 1 {
                    // No underscores in key, leave the word as is - maybe already camel cased
                    joinedString = String(stringKey[keyRange])
                } else {
                    joinedString = ([components[0].lowercased()] + components[1...].map { $0.capitalized }).joined()
                }

                // Do a cheap isEmpty check before creating and appending potentially empty strings
                let result: String
                if (leadingUnderscoreRange.isEmpty && trailingUnderscoreRange.isEmpty) {
                    result = joinedString
                } else if (!leadingUnderscoreRange.isEmpty && !trailingUnderscoreRange.isEmpty) {
                    // Both leading and trailing underscores
                    result = String(stringKey[leadingUnderscoreRange]) + joinedString + String(stringKey[trailingUnderscoreRange])
                } else if (!leadingUnderscoreRange.isEmpty) {
                    // Just leading
                    result = String(stringKey[leadingUnderscoreRange]) + joinedString
                } else {
                    // Just trailing
                    result = joinedString + String(stringKey[trailingUnderscoreRange])
                }
                return result
            }
        }

        let boolFlags: Bool
        let arraySeparators: [Character]
        let dateDecodingStrategy: DateDecodingStrategy
        let userInfo: [CodingUserInfoKey: Any]

        /// Creates a new `URLEncodedFormCodingConfiguration`.
        /// - parameters:
        ///     - boolFlags: Set to `true` allows you to parse `flag1&flag2` as boolean variables
        ///                  where object with variable `flag1` and `flag2` would decode to `true`
        ///                  or `false` depending on if the value was present or not. If this flag is set to
        ///                  true, it will always resolve for an optional `Bool`.
        ///     - arraySeparators: Uses these characters to decode arrays. If set to `,`, `arr=v1,v2` would
        ///                        populate a key named `arr` of type `Array` to be decoded as `["v1", "v2"]`
        ///     - dateDecodingStrategy: Date format used to decode a date. Date formats are tried in the order provided
        public init(
            boolFlags: Bool = true,
            arraySeparators: [Character] = [",", "|"],
            dateDecodingStrategy: DateDecodingStrategy = .secondsSince1970,
            userInfo: [CodingUserInfoKey: Any] = [:]
        ) {
            self.boolFlags = boolFlags
            self.arraySeparators = arraySeparators
            self.dateDecodingStrategy = dateDecodingStrategy
            self.userInfo = userInfo
        }
    }


    /// The underlying `URLEncodedFormEncodedParser`
    private let parser: URLEncodedFormParser

    private let configuration: Configuration

    /// Create a new `URLEncodedFormDecoder`. Can be configured by using the global `ContentConfiguration` class
    ///
    ///     ContentConfiguration.global.use(urlDecoder: URLEncodedFormDecoder(bracketsAsArray: true, flagsAsBool: true, arraySeparator: nil))
    ///
    /// - parameters:
    ///     - configuration: Defines how decoding is done see `URLEncodedFormCodingConfig` for more information
    public init(
        configuration: Configuration = .init()
    ) {
        self.parser = URLEncodedFormParser()
        self.configuration = configuration
    }

    /// ``ContentDecoder`` conformance.
    public func decode<D>(_ decodable: D.Type, from body: ByteBuffer, headers: HTTPHeaders) throws -> D
        where D: Decodable
    {
        try self.decode(D.self, from: body, headers: headers, userInfo: [:])
    }

    /// ``ContentDecoder`` conformance.
    public func decode<D>(_ decodable: D.Type, from body: ByteBuffer, headers: HTTPHeaders, userInfo: [CodingUserInfoKey: Any]) throws -> D
        where D: Decodable
    {
        guard headers.contentType == .urlEncodedForm else {
            throw Abort(.unsupportedMediaType)
        }
        let string = body.getString(at: body.readerIndex, length: body.readableBytes) ?? ""
        return try self.decode(D.self, from: string, userInfo: userInfo)
    }

    /// Decodes the URL's query string to the type provided
    ///
    ///     let ziz = try URLEncodedFormDecoder().decode(Pet.self, from: "name=Ziz&type=cat")
    ///
    /// - Parameters:
    ///   - decodable: Type to decode to
    ///   - url: ``URI`` to read the query string from
    public func decode<D>(_ decodable: D.Type, from url: URI) throws -> D where D : Decodable {
        try self.decode(D.self, from: url, userInfo: [:])
    }

    /// Decodes the URL's query string to the type provided
    ///
    ///     let ziz = try URLEncodedFormDecoder().decode(Pet.self, from: "name=Ziz&type=cat")
    ///
    /// - Parameters:
    ///   - decodable: Type to decode to
    ///   - url: ``URI`` to read the query string from
    ///   - userInfo: Overrides the default coder user info
    public func decode<D>(_ decodable: D.Type, from url: URI, userInfo: [CodingUserInfoKey: Any]) throws -> D where D : Decodable {
        try self.decode(D.self, from: url.query ?? "", userInfo: userInfo)
    }

    /// Decodes an instance of the supplied ``Decodable`` type from a ``String``.
    ///
    ///     print(data) // "name=Vapor&age=3"
    ///     let user = try URLEncodedFormDecoder().decode(User.self, from: data)
    ///     print(user) // User
    ///
    /// - Parameters:
    ///   - decodable: Generic ``Decodable`` type (``D``) to decode.
    ///   - string: String to decode a ``D`` from.
    ///   - userInfo: Overrides the default coder user info
    /// - returns: An instance of the `Decodable` type (``D``).
    /// - throws: Any error that may occur while attempting to decode the specified type.
    public func decode<D>(_ decodable: D.Type, from string: String, userInfo: [CodingUserInfoKey: Any] = [:]) throws -> D where D : Decodable {
        let parsedData = try self.parser.parse(string)
        let configuration: Configuration
        if !userInfo.isEmpty { // Changing a coder's userInfo is a thread-unsafe mutation, operate on a copy
            configuration = .init(boolFlags: self.configuration.boolFlags, arraySeparators: self.configuration.arraySeparators, dateDecodingStrategy: self.configuration.dateDecodingStrategy, userInfo: self.configuration.userInfo.merging(userInfo) { $1 })
        } else {
            configuration = self.configuration
        }
        let convertedData = convertKeys(
            data: parsedData,
            codingPath: [],
            strategy: configuration.keyDecodingStrategy
        )
        let decoder = _Decoder(data: convertedData, codingPath: [], configuration: configuration)
        return try D(from: decoder)
    }
}

// MARK: Private

/// Private `Decoder`. See `URLEncodedFormDecoder` for public decoder.
private struct _Decoder: Decoder {
    var data: URLEncodedFormData
    var codingPath: [CodingKey]
    var configuration: Configuration

    /// See `Decoder`
    var userInfo: [CodingUserInfoKey: Any] { self.configuration.userInfo }

    /// Creates a new `_URLEncodedFormDecoder`.
    init(data: URLEncodedFormData, codingPath: [CodingKey], configuration: URLEncodedFormDecoder.Configuration) {
        self.data = data
        self.codingPath = codingPath
        self.configuration = configuration
    }

    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key>
        where Key: CodingKey
    {
        return KeyedDecodingContainer(KeyedContainer<Key>(
            data: data,
            codingPath: self.codingPath,
            configuration: configuration
        ))
    }

    struct KeyedContainer<Key>: KeyedDecodingContainerProtocol
        where Key: CodingKey
    {
        var data: URLEncodedFormData
        var codingPath: [CodingKey]
        var configuration: Configuration

        var allKeys: [Key] {
            return self.data.children.keys.compactMap { Key(stringValue: String($0)) }
        }

        init(
            data: URLEncodedFormData,
            codingPath: [CodingKey],
            configuration: Configuration
        ) {
            self.data = convertKeys(
                data: data,
                codingPath: codingPath,
                strategy: configuration.keyDecodingStrategy
            )
            self.codingPath = codingPath
            self.configuration = configuration
        }

        func contains(_ key: Key) -> Bool {
            return self.data.children[key.stringValue] != nil
        }

        func decodeNil(forKey key: Key) throws -> Bool {
            return self.data.children[key.stringValue] == nil
        }

        private func decodeDate(forKey key: Key) throws -> Date {
            //If we are trying to decode a required array, we might not have decoded a child, but we should still try to decode an empty array
            let child = self.data.children[key.stringValue] ?? []
            return try configuration.decodeDate(from: child, codingPath: self.codingPath, forKey: key)
        }

        func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T: Decodable {
            //Check if we received a date. We need the decode with the appropriate format
            guard !(T.self is Date.Type) else {
                return try decodeDate(forKey: key) as! T
            }
            //If we are trying to decode a required array, we might not have decoded a child, but we should still try to decode an empty array
            let child = self.data.children[key.stringValue] ?? []
            if let convertible = T.self as? URLQueryFragmentConvertible.Type {
                guard let value = child.values.last else {
                    if self.configuration.boolFlags {
                        //If no values found see if we are decoding a boolean
                        if let _ = T.self as? Bool.Type {
                            return self.data.values.contains(.urlDecoded(key.stringValue)) as! T
                        }
                    }
                    throw DecodingError.valueNotFound(T.self, at: self.codingPath + [key])
                }
                if let result = convertible.init(urlQueryFragmentValue: value) {
                    return result as! T
                } else {
                    throw DecodingError.typeMismatch(T.self, at: self.codingPath + [key])
                }
            } else {
                let decoder = _Decoder(data: child, codingPath: self.codingPath + [key], configuration: configuration)
                return try T(from: decoder)
            }
        }

        func nestedContainer<NestedKey>(
            keyedBy type: NestedKey.Type,
            forKey key: Key
        ) throws -> KeyedDecodingContainer<NestedKey>
            where NestedKey: CodingKey
        {
            let child = self.data.children[key.stringValue] ?? []

            return KeyedDecodingContainer(KeyedContainer<NestedKey>(data: child, codingPath: self.codingPath + [key], configuration: configuration))
        }

        func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
            let child = self.data.children[key.stringValue] ?? []

            return try UnkeyedContainer(
                data: child,
                codingPath: self.codingPath + [key],
                configuration: configuration
            )
        }

        func superDecoder() throws -> Decoder {
            let child = self.data.children["super"] ?? []

            return _Decoder(data: child, codingPath: self.codingPath + [BasicCodingKey.key("super")], configuration: self.configuration)
        }

        func superDecoder(forKey key: Key) throws -> Decoder {
            let child = self.data.children[key.stringValue] ?? []

            return _Decoder(data: child, codingPath: self.codingPath + [key], configuration: self.configuration)
        }
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        return try UnkeyedContainer(data: data, codingPath: codingPath, configuration: configuration)
    }

    struct UnkeyedContainer: UnkeyedDecodingContainer {
        let data: URLEncodedFormData
        let values: [URLQueryFragment]
        var codingPath: [CodingKey]
        var configuration: Configuration
        var allChildKeysAreNumbers: Bool

        var count: Int? {
            // Did we get an array with arr[0]=a&arr[1]=b indexing?
            if self.allChildKeysAreNumbers {
                return data.children.count
            }
            // No we got an array with arr[]=a&arr[]=b or arr=a&arr=b
            return self.values.count
        }
        var isAtEnd: Bool {
            guard let count = self.count else {
                return true
            }
            return currentIndex >= count
        }
        var currentIndex: Int

        init(
            data: URLEncodedFormData,
            codingPath: [CodingKey],
            configuration: Configuration
        ) throws {
            self.data = data
            self.codingPath = codingPath
            self.configuration = configuration
            self.currentIndex = 0
            // Did we get an array with arr[0]=a&arr[1]=b indexing?
            // Cache this result
            self.allChildKeysAreNumbers = data.children.count > 0 && data.allChildKeysAreSequentialIntegers

            if allChildKeysAreNumbers {
                self.values = data.values
            } else {
                // No we got an array with arr[]=a&arr[]=b or arr=a&arr=b
                var values = data.values
                // empty brackets turn into empty strings!
                if let valuesInBracket = data.children[""] {
                    values = values + valuesInBracket.values
                }

                // parse out any character separated array values
                self.values = try values.flatMap { value in
                    try value.asUrlEncoded()
                        .split(omittingEmptySubsequences: false,
                               whereSeparator: configuration.arraySeparators.contains)
                        .map { (ss: Substring) in
                            URLQueryFragment.urlEncoded(String(ss))
                        }
                }
            }
        }

        func decodeNil() throws -> Bool {
            return false
        }

        mutating func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
            defer { self.currentIndex += 1 }
            if self.allChildKeysAreNumbers {
                let childData = self.data.children[String(self.currentIndex)]!
                //We can force an unwrap because in the constructor
                // we checked data.allChildKeysAreNumbers
                let decoder = _Decoder(
                    data: childData,
                    codingPath: self.codingPath + [BasicCodingKey.index(self.currentIndex)],
                    configuration: self.configuration
                )
                return try T(from: decoder)
            } else {
                let value = self.values[self.currentIndex]
                // Check if we received a date. We need the decode with the appropriate format.
                guard !(T.self is Date.Type) else {
                    return try self.configuration.decodeDate(from: value, codingPath: self.codingPath, forKey: BasicCodingKey.index(self.currentIndex)) as! T
                }

                if let convertible = T.self as? URLQueryFragmentConvertible.Type {
                    if let result = convertible.init(urlQueryFragmentValue: value) {
                        return result as! T
                    } else {
                        throw DecodingError.typeMismatch(T.self, at: self.codingPath + [BasicCodingKey.index(self.currentIndex)])
                    }
                } else {
                    //We need to pass in the value to be decoded
                    let decoder = _Decoder(data: URLEncodedFormData(values: [value]), codingPath: self.codingPath + [BasicCodingKey.index(self.currentIndex)], configuration: self.configuration)
                    return try T(from: decoder)
                }
            }
        }

        mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
            throw DecodingError.typeMismatch([String: Decodable].self, at: self.codingPath + [BasicCodingKey.index(self.currentIndex)])
        }

        mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
            throw DecodingError.typeMismatch([Decodable].self, at: self.codingPath + [BasicCodingKey.index(self.currentIndex)])
        }

        mutating func superDecoder() throws -> Decoder {
            defer { self.currentIndex += 1 }
            let data = self.allChildKeysAreNumbers ? self.data.children[self.currentIndex.description]! : .init(values: [self.values[self.currentIndex]])
            return _Decoder(data: data, codingPath: self.codingPath + [BasicCodingKey.index(self.currentIndex)], configuration: self.configuration)
        }
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        return SingleValueContainer(data: self.data, codingPath: self.codingPath, configuration: self.configuration)
    }

    struct SingleValueContainer: SingleValueDecodingContainer {
        let data: URLEncodedFormData
        var codingPath: [CodingKey]
        var configuration: Configuration

        init(
            data: URLEncodedFormData,
            codingPath: [CodingKey],
            configuration: Configuration
        ) {
            self.data = data
            self.codingPath = codingPath
            self.configuration = configuration
        }

        func decodeNil() -> Bool {
            self.data.values.isEmpty
        }

        func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
            // Check if we received a date. We need the decode with the appropriate format.
            guard !(T.self is Date.Type) else {
                return try self.configuration.decodeDate(from: self.data, codingPath: self.codingPath, forKey: nil) as! T
            }
            if let convertible = T.self as? URLQueryFragmentConvertible.Type {
              guard let value = self.data.values.last else {
                    throw DecodingError.valueNotFound(T.self, at: self.codingPath)
                }
                if let result = convertible.init(urlQueryFragmentValue: value) {
                    return result as! T
                } else {
                    throw DecodingError.typeMismatch(T.self, at: self.codingPath)
                }
            } else {
                let decoder = _Decoder(data: self.data, codingPath: self.codingPath, configuration: self.configuration)
                return try T(from: decoder)
            }
        }
    }
}

private extension URLEncodedFormDecoder.Configuration {
    func decodeDate(from data: URLEncodedFormData, codingPath: [CodingKey], forKey key: CodingKey?) throws -> Date {
        let newCodingPath = codingPath + (key.map { [$0] } ?? [])
        switch dateDecodingStrategy {
        case .secondsSince1970:
            guard let value = data.values.last else {
                throw DecodingError.valueNotFound(Date.self, at: newCodingPath)
            }
            if let result = Date.init(urlQueryFragmentValue: value) {
                return result
            } else {
                throw DecodingError.typeMismatch(Date.self, at: newCodingPath)
            }
        case .iso8601:
            let decoder = _Decoder(data: data, codingPath: newCodingPath, configuration: self)
            let container = try decoder.singleValueContainer()
            if let date = ISO8601DateFormatter.threadSpecific.date(from: try container.decode(String.self)) {
                return date
            } else {
                throw DecodingError.dataCorrupted(.init(codingPath: newCodingPath, debugDescription: "Unable to decode date. Expecting ISO8601 formatted date"))
            }
        case .custom(let callback):
            let decoder = _Decoder(data: data, codingPath: newCodingPath, configuration: self)
            return try callback(decoder)
        }
    }

    func decodeDate(from data: URLQueryFragment, codingPath: [CodingKey], forKey key: CodingKey?) throws -> Date {
        try self.decodeDate(from: .init(values: [data]), codingPath: codingPath, forKey: key)
    }
}

private extension DecodingError {
    static func typeMismatch(_ type: Any.Type, at path: [CodingKey]) -> DecodingError {
        let pathString = path.map { $0.stringValue }.joined(separator: ".")
        let context = DecodingError.Context(
            codingPath: path,
            debugDescription: "Data found at '\(pathString)' was not \(type)"
        )
        return Swift.DecodingError.typeMismatch(type, context)
    }

    static func valueNotFound(_ type: Any.Type, at path: [CodingKey]) -> DecodingError {
        let pathString = path.map { $0.stringValue }.joined(separator: ".")
        let context = DecodingError.Context(
            codingPath: path,
            debugDescription: "No \(type) was found at '\(pathString)'"
        )
        return Swift.DecodingError.valueNotFound(type, context)
    }
}

private func convertKeys(
    data: URLEncodedFormData,
    codingPath: [any CodingKey],
    strategy: Configuration.KeyDecodingStrategy
) -> URLEncodedFormData {
    switch strategy {
    case .useDefaultKeys:
        return data
    case .convertFromSnakeCase:
        // Convert the snake case keys in the container to camel case.
        // If we hit a duplicate key after conversion, then we'll use the first one we saw.
        var converted = [String: URLEncodedFormData]()
        converted.reserveCapacity(data.children.count)
        data.children.forEach { (key, value) in
            converted[Configuration.KeyDecodingStrategy._convertFromSnakeCase(key)] = convertKeys(
                data: value,
                codingPath: codingPath,
                strategy: strategy
            )
        }
        return URLEncodedFormData(values: data.values, children: converted)
    case .custom(let converter):
        var converted = [String: URLEncodedFormData]()
        converted.reserveCapacity(data.children.count)
        data.children.forEach { (key, value) in
            var pathForKey = codingPath
            pathForKey.append(BasicCodingKey.key(key))
            converted[converter(pathForKey).stringValue] = convertKeys(
                data: value,
                codingPath: codingPath,
                strategy: strategy
            )
        }
        return URLEncodedFormData(values: data.values, children: converted)
    }
}
