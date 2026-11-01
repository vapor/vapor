#if OpenAPI

/// A decoder that records what a type's `init(from:)` asks for, instead of reading any data.
///
/// Every request is answered with a placeholder, so decoding runs to the end and leaves a
/// ``DecodedShape`` behind. A class, so the containers it hands out can write into it.
final class SchemaDecoder {
    /// The types being decoded from the root down to this one, to spot recursion.
    let path: [Any.Type]
    let codingPath: [any CodingKey]
    /// Shared by every decoder in one run.
    let cache: Cache
    /// What the containers have recorded so far.
    var kind: DecodedShape.Kind = .empty
    var isNullable = false

    var userInfo: [CodingUserInfoKey: Any] {
        [:]
    }

    /// The one key a dictionary is offered, so its value type gets decoded once.
    ///
    /// String and `Int` keys accept it; synthesized `CodingKeys` don't, since a property name
    /// can't start with a digit.
    // TODO: Dictionaries with other keys, such as `[Role: Int]`, decode differently and fail.
    static let dictionaryKey = "0"

    init(path: [Any.Type], codingPath: [any CodingKey], cache: Cache) {
        self.path = path
        self.codingPath = codingPath
        self.cache = cache
    }

    /// The shape of `type`, or an error naming the path that couldn't be decoded.
    static func shape<T: Decodable>(of type: T.Type) throws -> DecodedShape {
        let cache = Cache()
        while true {
            let cachedCount = cache.values.count
            cache.endedRecursion = false
            let shape = try SchemaDecoder(path: [], codingPath: [], cache: cache).decodeNested(type).shape
            // A type between a recursion and the array that ended it stopped at the recursive property.
            // Each run caches more values to answer such properties with, so run again until none is left,
            // or until a run caches nothing new and the next would come out the same.
            guard cache.endedRecursion, cache.values.count > cachedCount else { return shape }
        }
    }

    /// Values decoded in a run, to stand in for a type when it turns up inside itself.
    final class Cache {
        var values: [ObjectIdentifier: Any] = [:]
        /// Whether an array or optional ended a recursion, leaving types around it partly decoded.
        var endedRecursion = false
    }

    /// Decodes `type` with a child decoder, returning a value for the caller and its shape.
    func decodeNested<T: Decodable>(_ type: T.Type) throws -> (value: T, shape: DecodedShape) {
        if let placeholder = Placeholder.value(for: type) {
            return (placeholder, DecodedShape(type: type, kind: .leaf))
        }
        // A provider's own placeholder skips an init(from:) that may reject ours.
        if let provider = type as? any OpenAPISchemaProvider.Type,
            let placeholder = provider.openAPIPlaceholder as? T
        {
            return (placeholder, DecodedShape(type: type, kind: .leaf))
        }

        // Wrappers never recurse themselves; what they hold does.
        if !Self.canBeEmpty(type), path.contains(where: { ObjectIdentifier($0) == ObjectIdentifier(type) }) {
            let recursive = DecodedShape(type: type, kind: .recursive)
            if let cached = cache.values[ObjectIdentifier(type)] as? T {
                return (cached, recursive)
            }
            throw RecursionFound(recursiveType: type, shape: recursive)
        }

        let child = SchemaDecoder(path: path + [type], codingPath: codingPath, cache: cache)

        do {
            let value = try T(from: child)
            if !Self.canBeEmpty(type) {
                cache.values[ObjectIdentifier(type)] = value
            }
            let decodedShape = DecodedShape(type: type, kind: child.kind, isNullable: child.isNullable)
            return (value, decodedShape)
        } catch let recursion as RecursionFound {
            // The nearest array or optional around the recursion ends it with an empty value.
            let decodedShape = DecodedShape(type: type, kind: child.kind, isNullable: child.isNullable)
            cache.endedRecursion = true
            if let empty = (T.self as? any RangeReplaceableCollection.Type)?.init() as? T {
                return (empty, decodedShape)
            }
            if let empty = (T.self as? any EmptyInitializable.Type)?.init() as? T {
                return (empty, decodedShape)
            }
            if let none = (T.self as? any ExpressibleByNilLiteral.Type)?.init(nilLiteral: ()) as? T {
                return (none, decodedShape)
            }
            // A plain type in between passes it up, so `Parent → [Child] → Parent` ends at the array.
            guard ObjectIdentifier(recursion.recursiveType) == ObjectIdentifier(type) else {
                throw RecursionFound(recursiveType: recursion.recursiveType, shape: decodedShape)
            }
            throw SchemaDecodingError(
                type: type,
                codingPath: codingPath,
                reason: "it contains itself with no array or optional to end the recursion"
            )
        } catch let error as SchemaDecodingError {
            // Already describes the type that failed; don't wrap it again on the way up.
            throw error
        } catch {
            // The type rejected a placeholder. An enum can still be decoded as its first case.
            let decodedShape = DecodedShape(type: type, kind: child.kind, isNullable: child.isNullable)
            if let first = (T.self as? any CaseIterable.Type)?.allCases.first as? T {
                return (first, decodedShape)
            }
            throw SchemaDecodingError(type: type, codingPath: codingPath, reason: reason(for: error))
        }
    }

    /// The message of a `DecodingError`, without its case name and coding path.
    private func reason(for error: any Error) -> String {
        switch error as? DecodingError {
        case .dataCorrupted(let context),
            .typeMismatch(_, let context),
            .valueNotFound(_, let context),
            .keyNotFound(_, let context):
            context.debugDescription
        default:
            "\(error)"
        }
    }

    /// Whether `type` can stand in empty or `nil`: arrays, sets, dictionaries and optionals.
    static func canBeEmpty(_ type: Any.Type) -> Bool {
        type is any RangeReplaceableCollection.Type
            || type is any EmptyInitializable.Type
            || type is any ExpressibleByNilLiteral.Type
    }

    /// Adds a property to the object being recorded.
    func append(_ field: DecodedShape.Field) {
        guard case .keyed(var fields) = kind else { return }
        fields.append(field)
        kind = .keyed(fields)
    }
}

extension SchemaDecoder: Decoder {
    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        kind = .keyed([])
        let keyedContainer = KeyedContainer<Key>(decoder: self)
        let keyedDecodingContainer = KeyedDecodingContainer(keyedContainer)
        return keyedDecodingContainer
    }

    func unkeyedContainer() throws -> any UnkeyedDecodingContainer {
        kind = .unkeyed(nil)
        let unkeyedContainer = UnkeyedContainer(decoder: self)
        return unkeyedContainer
    }

    func singleValueContainer() throws -> any SingleValueDecodingContainer {
        SingleContainer(decoder: self)
    }
}

extension SchemaDecoder {
    /// Records each decoded key as a property, or a dictionary's value for ``SchemaDecoder/dictionaryKey``.
    struct KeyedContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
        let decoder: SchemaDecoder
        var codingPath: [any CodingKey] { decoder.codingPath }
        var allKeys: [Key] {
            if let key = Key(stringValue: dictionaryKey) {
                return [key]
            }
            return []
        }

        func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
            try decodeField(type, forKey: key, isOptional: false)
        }

        func decodeIfPresent<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T? {
            // An optional property ends recursion with `nil`; the property is already recorded.
            do {
                return try decodeField(type, forKey: key, isOptional: true)
            } catch is RecursionFound {
                return nil
            }
        }

        // The protocol's defaults for these would win over the generic methods above: its
        // `decodeIfPresent` overloads call `decode`, losing optionality, and its 128-bit `decode`s throw.
        func decode(_ type: Int128.Type, forKey key: Key) throws -> Int128 {
            try decodeField(type, forKey: key, isOptional: false)
        }

        func decode(_ type: UInt128.Type, forKey key: Key) throws -> UInt128 {
            try decodeField(type, forKey: key, isOptional: false)
        }

        func decodeIfPresent(_ type: Bool.Type, forKey key: Key) throws -> Bool? {
            try decodeField(type, forKey: key, isOptional: true)
        }

        func decodeIfPresent(_ type: String.Type, forKey key: Key) throws -> String? {
            try decodeField(type, forKey: key, isOptional: true)
        }

        func decodeIfPresent(_ type: Double.Type, forKey key: Key) throws -> Double? {
            try decodeField(type, forKey: key, isOptional: true)
        }

        func decodeIfPresent(_ type: Float.Type, forKey key: Key) throws -> Float? {
            try decodeField(type, forKey: key, isOptional: true)
        }

        func decodeIfPresent(_ type: Int.Type, forKey key: Key) throws -> Int? {
            try decodeField(type, forKey: key, isOptional: true)
        }

        func decodeIfPresent(_ type: Int8.Type, forKey key: Key) throws -> Int8? {
            try decodeField(type, forKey: key, isOptional: true)
        }

        func decodeIfPresent(_ type: Int16.Type, forKey key: Key) throws -> Int16? {
            try decodeField(type, forKey: key, isOptional: true)
        }

        func decodeIfPresent(_ type: Int32.Type, forKey key: Key) throws -> Int32? {
            try decodeField(type, forKey: key, isOptional: true)
        }

        func decodeIfPresent(_ type: Int64.Type, forKey key: Key) throws -> Int64? {
            try decodeField(type, forKey: key, isOptional: true)
        }

        func decodeIfPresent(_ type: Int128.Type, forKey key: Key) throws -> Int128? {
            try decodeField(type, forKey: key, isOptional: true)
        }

        func decodeIfPresent(_ type: UInt.Type, forKey key: Key) throws -> UInt? {
            try decodeField(type, forKey: key, isOptional: true)
        }

        func decodeIfPresent(_ type: UInt8.Type, forKey key: Key) throws -> UInt8? {
            try decodeField(type, forKey: key, isOptional: true)
        }

        func decodeIfPresent(_ type: UInt16.Type, forKey key: Key) throws -> UInt16? {
            try decodeField(type, forKey: key, isOptional: true)
        }

        func decodeIfPresent(_ type: UInt32.Type, forKey key: Key) throws -> UInt32? {
            try decodeField(type, forKey: key, isOptional: true)
        }

        func decodeIfPresent(_ type: UInt64.Type, forKey key: Key) throws -> UInt64? {
            try decodeField(type, forKey: key, isOptional: true)
        }

        func decodeIfPresent(_ type: UInt128.Type, forKey key: Key) throws -> UInt128? {
            try decodeField(type, forKey: key, isOptional: true)
        }

        // Every key is present and not null, so custom `init(from:)`s decode all their properties.
        func contains(_ key: Key) -> Bool {
            true
        }

        func decodeNil(forKey key: Key) throws -> Bool {
            false
        }

        func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<
            NestedKey
        > {
            throw DecodingError.dataCorrupted(
                .init(codingPath: codingPath + [key], debugDescription: "Nested containers aren't supported yet")
            )
        }

        func nestedUnkeyedContainer(forKey key: Key) throws -> any UnkeyedDecodingContainer {
            throw DecodingError.dataCorrupted(
                .init(codingPath: codingPath + [key], debugDescription: "Nested unkeyed containers aren't supported yet")
            )
        }

        func superDecoder() throws -> any Decoder {
            throw DecodingError.dataCorrupted(
                .init(codingPath: codingPath, debugDescription: "Super decoders aren't supported yet")
            )
        }

        func superDecoder(forKey key: Key) throws -> any Decoder {
            throw DecodingError.dataCorrupted(
                .init(codingPath: codingPath + [key], debugDescription: "Super decoders aren't supported yet")
            )
        }

        private func decodeField<T: Decodable>(_ type: T.Type, forKey key: Key, isOptional: Bool) throws -> T {
            let fieldDecoder = SchemaDecoder(path: decoder.path, codingPath: decoder.codingPath + [key], cache: decoder.cache)
            do {
                let (value, shape) = try fieldDecoder.decodeNested(type)
                let field = DecodedShape.Field(name: key.stringValue, shape: shape, isOptional: isOptional)
                if key.stringValue == dictionaryKey {
                    decoder.kind = .dictionary(shape)
                } else {
                    decoder.append(field)
                }
                return value
            } catch let error as RecursionFound {
                if key.stringValue == dictionaryKey {
                    decoder.kind = .dictionary(error.shape)
                } else {
                    decoder.append(.init(name: key.stringValue, shape: error.shape, isOptional: isOptional))
                }
                throw error
            }
        }
    }
}

extension SchemaDecoder {
    /// Records the element of an array, decoding exactly one before reporting the end.
    struct UnkeyedContainer: UnkeyedDecodingContainer {
        let decoder: SchemaDecoder
        var currentIndex: Int = 0
        var codingPath: [any CodingKey] {
            decoder.codingPath
        }

        var count: Int? {
            nil
        }

        var isAtEnd: Bool {
            currentIndex > 0
        }

        mutating func decodeNil() throws -> Bool {
            false
        }

        mutating func decode<T: Decodable>(_ type: T.Type) throws -> T {
            try decodeElement(type)
        }

        // The protocol's default 128-bit `decode`s throw, and would win over the generic one.
        mutating func decode(_ type: Int128.Type) throws -> Int128 {
            try decodeElement(type)
        }

        mutating func decode(_ type: UInt128.Type) throws -> UInt128 {
            try decodeElement(type)
        }

        mutating func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> {
            throw DecodingError.dataCorrupted(
                .init(codingPath: codingPath, debugDescription: "Nested containers aren't supported yet")
            )
        }

        mutating func nestedUnkeyedContainer() throws -> any UnkeyedDecodingContainer {
            throw DecodingError.dataCorrupted(
                .init(codingPath: codingPath, debugDescription: "Nested unkeyed containers aren't supported yet")
            )
        }

        mutating func superDecoder() throws -> any Decoder {
            throw DecodingError.dataCorrupted(
                .init(codingPath: codingPath, debugDescription: "Super decoders aren't supported yet")
            )
        }

        private mutating func decodeElement<T: Decodable>(_ type: T.Type) throws -> T {
            let elementDecoder = SchemaDecoder(path: decoder.path, codingPath: decoder.codingPath, cache: decoder.cache)
            do {
                let (value, shape) = try elementDecoder.decodeNested(type)
                decoder.kind = .unkeyed(shape)
                currentIndex += 1
                return value
            } catch let error as RecursionFound {
                decoder.kind = .unkeyed(error.shape)
                throw error
            }
        }
    }
}

extension SchemaDecoder {
    /// Records the value a wrapper holds, and whether it checked for `null`.
    struct SingleContainer: SingleValueDecodingContainer {
        let decoder: SchemaDecoder

        var codingPath: [any CodingKey] {
            decoder.codingPath
        }

        func decodeNil() -> Bool {
            decoder.isNullable = true
            return false
        }

        func decode<T: Decodable>(_ type: T.Type) throws -> T {
            try decodeValue(type)
        }

        // The protocol's default 128-bit `decode`s throw, and would win over the generic one.
        func decode(_ type: Int128.Type) throws -> Int128 {
            try decodeValue(type)
        }

        func decode(_ type: UInt128.Type) throws -> UInt128 {
            try decodeValue(type)
        }

        private func decodeValue<T: Decodable>(_ type: T.Type) throws -> T {
            do {
                let valueDecoder = SchemaDecoder(path: decoder.path, codingPath: decoder.codingPath, cache: decoder.cache)
                let (value, shape) = try valueDecoder.decodeNested(type)
                decoder.kind = .single(shape)
                return value
            } catch let error as RecursionFound {
                decoder.kind = .single(error.shape)
                throw error
            }
        }
    }
}

extension SchemaDecoder {
    /// Raised where a type turns up inside itself, and caught by the nearest array or optional.
    private struct RecursionFound: Error {
        /// The type that recurses.
        let recursiveType: Any.Type
        /// The shape the catching container records: the recursion, or a type it passed through.
        let shape: DecodedShape
    }

    /// A type that can't be decoded from placeholders, with the path that led to it.
    private struct SchemaDecodingError: Error, CustomStringConvertible {
        let type: Any.Type
        let codingPath: [any CodingKey]
        let reason: String

        var description: String {
            let path = codingPath.map(\.stringValue).joined(separator: ".")
            // DecodingError descriptions often end in a full stop already.
            let reason = reason.hasSuffix(".") ? String(reason.dropLast()) : reason
            return "\(path.isEmpty ? "\(type)" : path): can't describe \(type), \(reason). "
                + "Make it CaseIterable if it's an enum, accept placeholder values in its init(from:), "
                + "or give it a `static var openAPIPlaceholder: Self?` through OpenAPISchemaProvider."
        }
    }
}

/// Collections that aren't `RangeReplaceableCollection` but can still be created empty,
/// so recursion through them can be ended like through an array.
protocol EmptyInitializable {
    init()
}

extension Set: EmptyInitializable {}
extension Dictionary: EmptyInitializable {}

#endif
