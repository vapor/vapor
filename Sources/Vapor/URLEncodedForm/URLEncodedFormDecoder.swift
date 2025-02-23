import NIOCore
import Foundation
import NIOHTTP1

/// Decodes instances of `Decodable` types from `application/x-www-form-urlencoded` data.
///
/// ```swift
/// print(data) // "name=Vapor&age=3"
/// let user = try URLEncodedFormDecoder().decode(User.self, from: data)
/// print(user) // User
/// ```
///
/// URL-encoded forms are commonly used by websites to send form data via POST requests. This encoding is relatively
/// efficient for small amounts of data but must be percent-encoded. `multipart/form-data` is more efficient for
/// sending larger data blobs like files, and `application/json` encoding has become increasingly common.
///
/// See [the offical WhatWG URL standard](https://url.spec.whatwg.org/#application/x-www-form-urlencoded) for more
/// information about the "URL-encoded WWW form" format.
public struct URLEncodedFormDecoder: ContentDecoder, URLQueryDecoder, Sendable {
    /// Ecapsulates configuration options for URL-encoded form decoding.
    public struct Configuration: Sendable {
        /// Supported date formats
        public enum DateDecodingStrategy: Sendable {
            /// Decodes integer or floating-point values expressed as seconds since the UNIX
            /// epoch (`1970-01-01 00:00:00.000Z`).
            case secondsSince1970

            /// Decodes ISO-8601 formatted date strings.
            case iso8601

            /// Invokes a custom callback to decode values when a date is requested.
            case custom(@Sendable (Decoder) throws -> Date)
        }

        let boolFlags: Bool
        let arraySeparators: [Character]
        let dateDecodingStrategy: DateDecodingStrategy
        let userInfo: [CodingUserInfoKey: Sendable]
        
        /// Creates a new ``URLEncodedFormDecoder/Configuration``.
        ///
        /// - Parameters:
        ///   - boolFlags: When `true`, form data such as `flag1&flag2` will be interpreted as boolean flags, where
        ///     the resulting value is true if the flag name exists and false if it does not. When `false`, such data
        ///     is interpreted as keys having no values.
        ///   - arraySeparators: A set of characters to be treated as value separators for array values. For example,
        ///     using the default of `[",", "|"]`, both `arr=v1,v2` and `arr=v1|v2` are decoded as an array named `arr`
        ///     with the two values `v1` and `v2`.
        ///   - dateDecodingStrategy: The ``URLEncodedFormDecoder/Configuration/DateDecodingStrategy`` to use for
        ///     date decoding.
        ///   - userInfo: Additional and/or overriding user info keys for the underlying `Decoder` (you probably
        ///     don't need this).
        public init(
            boolFlags: Bool = true,
            arraySeparators: [Character] = [",", "|"],
            dateDecodingStrategy: DateDecodingStrategy = .secondsSince1970,
            userInfo: [CodingUserInfoKey: Sendable] = [:]
        ) {
            self.boolFlags = boolFlags
            self.arraySeparators = arraySeparators
            self.dateDecodingStrategy = dateDecodingStrategy
            self.userInfo = userInfo
        }
    }

    /// The underlying ``URLEncodedFormParser``.
    private let parser: URLEncodedFormParser

    /// The decoder's configuration.
    private let configuration: Configuration

    /// Create a new ``URLEncodedFormDecoder``.
    ///
    /// Typically configured via ``ContentConfiguration``:
    ///
    /// ```swift
    /// let contentConfiguration = ContentConfiguration.default()
    /// contentConfiguration.use(urlDecoder: URLEncodedFormDecoder(
    ///     bracketsAsArray: true,
    ///     flagsAsBool: true,
    ///     arraySeparator: nil
    /// ))
    /// ```
    ///
    /// - Parameter configuration: A ``URLEncodedFormDecoder/Configuration`` specifying the decoder's behavior.
    public init(configuration: Configuration = .init()) {
        self.parser = URLEncodedFormParser()
        self.configuration = configuration
    }
    
    // See `ContentDecoder.decode(_:from:headers:)`.
    public func decode<D: Decodable>(_: D.Type, from body: ByteBuffer, headers: HTTPHeaders) throws -> D {
        try self.decode(D.self, from: body, headers: headers, userInfo: [:])
    }
    
    // See `ContentDecoder.decode(_:from:headers:userInfo:)`.
    public func decode<D: Decodable>(_: D.Type, from body: ByteBuffer, headers: HTTPHeaders, userInfo: [CodingUserInfoKey: Sendable]) throws -> D {
        guard headers.contentType == .urlEncodedForm else {
            throw Abort(.unsupportedMediaType)
        }
        
        let string = body.getString(at: body.readerIndex, length: body.readableBytes) ?? ""
        
        return try self.decode(D.self, from: string, userInfo: userInfo)
    }

    // See `URLQueryDecoder.decode(_:from:)`.
    public func decode<D: Decodable>(_: D.Type, from url: URI) throws -> D {
        try self.decode(D.self, from: url, userInfo: [:])
    }
    
    // See `URLQueryDecoder.decode(_:from:userInfo:)`.
    public func decode<D: Decodable>(_: D.Type, from url: URI, userInfo: [CodingUserInfoKey: Sendable]) throws -> D {
        try self.decode(D.self, from: url.query ?? "", userInfo: userInfo)
    }

    /// Decodes an instance of the supplied `Decodable` type from a `String`.
    ///
    /// ```swift
    /// print(data) // "name=Vapor&age=3"
    /// let user = try URLEncodedFormDecoder().decode(User.self, from: data)
    /// print(user) // User
    /// ```
    ///
    /// - Parameters:
    ///   - decodable: A `Decodable` type `D` to decode.
    ///   - string: String to decode a `D` from.
    /// - Returns: An instance of `D`.
    /// - Throws: Any error that may occur while attempting to decode the specified type.
    public func decode<D: Decodable>(_: D.Type, from string: String) throws -> D {
        /// This overload did not previously exist; instead, the much more obvious approach of defaulting the
        /// `userInfo` argument of ``decode(_:from:userInfo:)-6h3y5`` was taken. Unfortunately, this resulted
        /// in the compiler calling ``decode(_:from:)-7fve9`` via ``URI``'s conformance to
        /// `ExpressibleByStringInterpolation` preferentially when a caller did not provide their own user info (so,
        /// always). This, completely accidentally, did the "right thing" in the past thanks to a quirk of the
        /// ancient and badly broken C-based URI parser. That parser no longer being in use, it is now necessary to
        /// provide the explicit overload to convince the compiler to do the right thing. (`@_disfavoredOverload` was
        /// considered and rejected as an alternative option - using it caused an infinite loop between
        /// ``decode(_:from:userInfo:)-893nd`` and ``URLQueryDecoder/decode(_:from:)`` when built on Linux.
        ///
        /// None of this, of course, was in any way whatsoever confusing in the slightest. Indeed, Tanner's choice to
        /// makie ``URI`` `ExpressibleByStringInterpolation` (and, for that matter, `ExpressibleByStringLiteral`)
        /// back in 2019 was unquestionably just, just a truly _awesome_ and _inspired_ design decision 🤥.
        try self.decode(D.self, from: string, userInfo: [:])
    }

    /// Decodes an instance of the supplied `Decodable` type from a `String`.
    ///
    /// ```swift
    /// print(data) // "name=Vapor&age=3"
    /// let user = try URLEncodedFormDecoder().decode(User.self, from: data, userInfo: [...])
    /// print(user) // User
    /// ```
    ///
    /// - Parameters:
    ///   - decodable: A `Decodable` type `D` to decode.
    ///   - string: String to decode a `D` from.
    ///   - userInfo: Overrides and/or augments the default coder user info.
    /// - Returns: An instance of `D`.
    /// - Throws: Any error that may occur while attempting to decode the specified type.
    public func decode<D: Decodable>(_: D.Type, from string: String, userInfo: [CodingUserInfoKey: Sendable]) throws -> D {
        let configuration: URLEncodedFormDecoder.Configuration
        
        if !userInfo.isEmpty { // Changing a coder's userInfo is a thread-unsafe mutation, operate on a copy
            configuration = .init(
                boolFlags: self.configuration.boolFlags,
                arraySeparators: self.configuration.arraySeparators,
                dateDecodingStrategy: self.configuration.dateDecodingStrategy,
                userInfo: self.configuration.userInfo.merging(userInfo) { $1 }
            )
        } else {
            configuration = self.configuration
        }
        
        let parsedData = try self.parser.parse(string)
        let decoder = _Decoder(data: parsedData, codingPath: [], configuration: configuration)
        
        return try D(from: decoder)
    }
}

// MARK: Private

/// Private `Decoder`. See `URLEncodedFormDecoder` for public decoder.
private struct _Decoder: Decoder {
    var data: URLEncodedFormData
    var configuration: URLEncodedFormDecoder.Configuration
    
    // See `Decoder.codingPath`
    var codingPath: [CodingKey]

    // See `Decoder.userInfo`
    var userInfo: [CodingUserInfoKey: Any] { self.configuration.userInfo }
    
    /// Creates a new `_Decoder`.
    init(data: URLEncodedFormData, codingPath: [CodingKey], configuration: URLEncodedFormDecoder.Configuration) {
        self.data = data
        self.codingPath = codingPath
        self.configuration = configuration
    }
    
    func container<Key: CodingKey>(keyedBy: Key.Type) throws -> KeyedDecodingContainer<Key> {
        .init(KeyedContainer<Key>(
            data: self.data,
            codingPath: self.codingPath,
            configuration: self.configuration
        ))
    }
    
    struct KeyedContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
        let data: URLEncodedFormData
        var codingPath: [CodingKey]
        var configuration: URLEncodedFormDecoder.Configuration

        var allKeys: [Key] {
            (self.data.children.keys + self.data.values.compactMap { try? $0.asUrlDecoded() }).compactMap { Key(stringValue: String($0)) }
        }
        
        init(
            data: URLEncodedFormData,
            codingPath: [CodingKey],
            configuration: URLEncodedFormDecoder.Configuration
        ) {
            self.data = data
            self.codingPath = codingPath
            self.configuration = configuration
        }
        
        func contains(_ key: Key) -> Bool {
            self.data.children[key.stringValue] != nil || self.data.values.contains(.init(stringLiteral: key.stringValue))
        }
        
        func decodeNil(forKey key: Key) throws -> Bool {
            self.data.children[key.stringValue] == nil && !self.data.values.contains(.init(stringLiteral: key.stringValue))
        }
        
        private func decodeDate(forKey key: Key, child: URLEncodedFormData) throws -> Date {
            try configuration.decodeDate(from: child, codingPath: self.codingPath, forKey: key)
        }
        
        func decode<T: Decodable>(_: T.Type, forKey key: Key) throws -> T {
            // If we are trying to decode a required array, we might not have decoded a child, but we should
            // still try to decode an empty array
            let child = self.data.children[key.stringValue] ?? []

            // If decoding a date, we need to apply the configured date decoding strategy.
            if T.self is Date.Type {
                return try self.decodeDate(forKey: key, child: child) as! T
            } else if let convertible = T.self as? URLQueryFragmentConvertible.Type {
                switch child.values.last {
                case let value?:
                    guard let result = convertible.init(urlQueryFragmentValue: value) else {
                        throw DecodingError.typeMismatch(T.self, at: self.codingPath + [key])
                    }
                    return result as! T
                case nil where self.configuration.boolFlags && T.self is Bool.Type:
                    // If there's no value, but flags are enabled and a Bool was requested, treat it as a flag.
                    return self.data.values.contains(.urlDecoded(key.stringValue)) as! T
                default:
                    throw DecodingError.valueNotFound(T.self, at: self.codingPath + [key])
                }
            } else {
                let decoder = _Decoder(data: child, codingPath: self.codingPath + [key], configuration: self.configuration)
                
                return try T.init(from: decoder)
            }
        }
        
        func nestedContainer<NestedKey: CodingKey>(keyedBy: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> {
            .init(KeyedContainer<NestedKey>(
                data: self.data.children[key.stringValue] ?? [],
                codingPath: self.codingPath + [key],
                configuration: self.configuration
            ))
        }
        
        func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
            try UnkeyedContainer(
                data: self.data.children[key.stringValue] ?? [],
                codingPath: self.codingPath + [key],
                configuration: self.configuration
            )
        }
        
        func superDecoder() throws -> Decoder {
            _Decoder(
                data: self.data.children["super"] ?? [],
                codingPath: self.codingPath + [BasicCodingKey.key("super")],
                configuration: self.configuration
            )
        }
        
        func superDecoder(forKey key: Key) throws -> Decoder {
            _Decoder(
                data: self.data.children[key.stringValue] ?? [],
                codingPath: self.codingPath + [key],
                configuration: self.configuration
            )
        }
    }
    
    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        try UnkeyedContainer(data: self.data, codingPath: self.codingPath, configuration: self.configuration)
    }
    
    struct UnkeyedContainer: UnkeyedDecodingContainer {
        let data: URLEncodedFormData
        let values: [URLQueryFragment]
        var codingPath: [CodingKey]
        var configuration: URLEncodedFormDecoder.Configuration
        var allChildKeysAreNumbers: Bool

        var count: Int? {
            if self.allChildKeysAreNumbers {
                // Did we get an array with arr[0]=a&arr[1]=b indexing?
                return data.children.count
            } else {
                // No, we got an array with arr[]=a&arr[]=b or arr=a&arr=b
                return self.values.count
            }
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
            configuration: URLEncodedFormDecoder.Configuration
        ) throws {
            self.data = data
            self.codingPath = codingPath
            self.configuration = configuration
            self.currentIndex = 0
            // Did we get an array with arr[0]=a&arr[1]=b indexing? Cache the result.
            self.allChildKeysAreNumbers = !data.children.isEmpty && data.allChildKeysAreSequentialIntegers
            
            if self.allChildKeysAreNumbers {
                self.values = data.values
            } else {
                // No, we got an array with arr[]=a&arr[]=b or arr=a&arr=b
                var values = data.values

                // Empty brackets turn into empty strings
                if let valuesInBracket = data.children[""] {
                    values += valuesInBracket.values
                }
                
                // Parse out any character-separated array values
                self.values = try values.flatMap {
                    try $0.asUrlEncoded()
                        .split(omittingEmptySubsequences: false, whereSeparator: configuration.arraySeparators.contains)
                        .map { .urlEncoded(.init($0)) }
                }

                if self.values.isEmpty && !data.children.isEmpty {
                    let context = DecodingError.Context(
                        codingPath: codingPath,
                        debugDescription: "Expected an array but could not parse the data as an array"
                    )
                    throw DecodingError.dataCorrupted(context)
                }
            }
        }
        
        func decodeNil() throws -> Bool {
            false
        }

        mutating func decode<T: Decodable>(_: T.Type) throws -> T {
            defer { self.currentIndex += 1 }
            
            guard !isAtEnd else {
                let context = DecodingError.Context(
                    codingPath: self.codingPath,
                    debugDescription: "Unkeyed container is at end."
                )
                throw DecodingError.valueNotFound(T.self, context)
            }
            
            if self.allChildKeysAreNumbers {
                // We can force-unwrap because we already checked data.allChildKeysAreNumbers in the initializer.
                let childData = self.data.children[String(self.currentIndex)]!
                let decoder = _Decoder(
                    data: childData,
                    codingPath: self.codingPath + [BasicCodingKey.index(self.currentIndex)],
                    configuration: self.configuration
                )
                
                return try T(from: decoder)
            } else {
                let value = self.values[self.currentIndex]
                
                if T.self is Date.Type {
                    return try self.configuration.decodeDate(
                        from: value,
                        codingPath: self.codingPath,
                        forKey: BasicCodingKey.index(self.currentIndex)
                    ) as! T
                } else if let convertible = T.self as? URLQueryFragmentConvertible.Type {
                    guard let result = convertible.init(urlQueryFragmentValue: value) else {
                        throw DecodingError.typeMismatch(T.self, at: self.codingPath + [BasicCodingKey.index(self.currentIndex)])
                    }
                    return result as! T
                } else {
                    let decoder = _Decoder(
                        data: URLEncodedFormData(values: [value]),
                        codingPath: self.codingPath + [BasicCodingKey.index(self.currentIndex)],
                        configuration: self.configuration
                    )
                    
                    return try T.init(from: decoder)
                }
            }
        }
        
        mutating func nestedContainer<NestedKey: CodingKey>(keyedBy: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> {
            throw DecodingError.typeMismatch([String: Decodable].self, at: self.codingPath + [BasicCodingKey.index(self.currentIndex)])
        }
        
        mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
            throw DecodingError.typeMismatch([Decodable].self, at: self.codingPath + [BasicCodingKey.index(self.currentIndex)])
        }
        
        mutating func superDecoder() throws -> Decoder {
            defer { self.currentIndex += 1 }
            
            let data = self.allChildKeysAreNumbers ? self.data.children[self.currentIndex.description]! : .init(values: [self.values[self.currentIndex]])
            
            return _Decoder(
                data: data,
                codingPath: self.codingPath + [BasicCodingKey.index(self.currentIndex)],
                configuration: self.configuration
            )
        }
    }
    
    func singleValueContainer() throws -> SingleValueDecodingContainer {
        SingleValueContainer(data: self.data, codingPath: self.codingPath, configuration: self.configuration)
    }
    
    struct SingleValueContainer: SingleValueDecodingContainer {
        let data: URLEncodedFormData
        var codingPath: [CodingKey]
        var configuration: URLEncodedFormDecoder.Configuration
        
        init(
            data: URLEncodedFormData,
            codingPath: [CodingKey],
            configuration: URLEncodedFormDecoder.Configuration
        ) {
            self.data = data
            self.codingPath = codingPath
            self.configuration = configuration
        }
        
        func decodeNil() -> Bool {
            self.data.values.isEmpty
        }
        
        func decode<T: Decodable>(_: T.Type) throws -> T {
            if T.self is Date.Type {
                return try self.configuration.decodeDate(from: self.data, codingPath: self.codingPath, forKey: nil) as! T
            } else if let convertible = T.self as? URLQueryFragmentConvertible.Type {
                guard let value = self.data.values.last else {
                    throw DecodingError.valueNotFound(T.self, at: self.codingPath)
                }
                guard let result = convertible.init(urlQueryFragmentValue: value) else {
                    throw DecodingError.typeMismatch(T.self, at: self.codingPath)
                }
                
                return result as! T
            } else {
                let decoder = _Decoder(
                    data: self.data,
                    codingPath: self.codingPath,
                    configuration: self.configuration
                )
                
                return try T(from: decoder)
            }
        }
    }
}

private extension URLEncodedFormDecoder.Configuration {
    func decodeDate(from data: URLEncodedFormData, codingPath: [CodingKey], forKey key: CodingKey?) throws -> Date {
        let newCodingPath = codingPath + (key.map { [$0] } ?? [])
        
        switch self.dateDecodingStrategy {
        case .secondsSince1970:
            guard let value = data.values.last else {
                throw DecodingError.valueNotFound(Date.self, at: newCodingPath)
            }
            guard let result = Date(urlQueryFragmentValue: value) else {
                throw DecodingError.typeMismatch(Date.self, at: newCodingPath)
            }

            return result
        case .iso8601:
            let decoder = _Decoder(data: data, codingPath: newCodingPath, configuration: self)
            let container = try decoder.singleValueContainer()

            guard let date = ISO8601DateFormatter().date(from: try container.decode(String.self)) else {
                throw DecodingError.dataCorrupted(.init(codingPath: newCodingPath, debugDescription: "Unable to decode ISO-8601 date."))
            }
            return date
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
        let pathString = path.map(\.stringValue).joined(separator: ".")
        let context = DecodingError.Context(
            codingPath: path,
            debugDescription: "Data found at '\(pathString)' was not \(type)"
        )
        
        return .typeMismatch(type, context)
    }
    
    static func valueNotFound(_ type: Any.Type, at path: [CodingKey]) -> DecodingError {
        let pathString = path.map(\.stringValue).joined(separator: ".")
        let context = DecodingError.Context(
            codingPath: path,
            debugDescription: "No \(type) was found at '\(pathString)'"
        )
        
        return .valueNotFound(type, context)
    }
}
