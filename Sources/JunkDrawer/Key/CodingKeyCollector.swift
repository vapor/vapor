extension Decodable {
    /// Collect's the Decodable type's properties into an
    /// array of `CodingKeyProperty` using the `init(from: Decoder)` method.
    /// - parameter depth: Controls how deeply nested optional decoding will go.
    public static func properties(depth: Int = 1) -> [CodingKeyProperty] {
        let result = CodingKeyCollectorResult(depth: depth)
        let decoder = CodingKeyCollector(codingPath: [], result: result)
        _ = try! Self(from: decoder)
        return result.properties
    }
}

/// A property from a Decodable type.
public struct CodingKeyProperty {
    /// The coding path to this property.
    public let codingPath: [CodingKey]

    /// This property's type.
    public let type: Any.Type

    /// True if the original property is optional.
    public let isOptional: Bool
}

extension CodingKeyProperty: CustomStringConvertible {
    /// See CustomStringConvertible.description
    public var description: String {
        let path = codingPath.map { $0.stringValue }.joined(separator: ".")
        return "\(path): \(type)\(isOptional ? "?" : "")"
    }
}

fileprivate final class CodingKeyCollectorResult {
    var properties: [CodingKeyProperty]
    var depth: Int
    var isOptional: Bool

    init(depth: Int) {
        self.depth = depth
        properties = []
        isOptional = false
    }

    func add(type: Any.Type, atPath codingPath: [CodingKey]) {
        let property = CodingKeyProperty(codingPath: codingPath, type: type, isOptional: isOptional)
        isOptional = false
        properties.append(property)
    }
}

fileprivate final class CodingKeyCollector: Decoder {
    var codingPath: [CodingKey]
    var result: CodingKeyCollectorResult
    var userInfo: [CodingUserInfoKey: Any]

    init(codingPath: [CodingKey], result: CodingKeyCollectorResult) {
        self.codingPath = codingPath
        self.result = result
        userInfo = [:]
    }

    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
        let container = CodingKeyCollectorKeyedDecoder<Key>(
            codingPath: codingPath,
            result: result
        )
        return KeyedDecodingContainer(container)
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        fatalError("key string mapping arrays is not yet supported")
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        return CodingKeyCollectorSingleValueDecoder(codingPath: codingPath, result: result)
    }
}

fileprivate struct CodingKeyCollectorSingleValueDecoder: SingleValueDecodingContainer {
    var codingPath: [CodingKey]
    var result: CodingKeyCollectorResult

    init(codingPath: [CodingKey], result: CodingKeyCollectorResult) {
        self.codingPath = codingPath
        self.result = result
    }

    func decodeNil() -> Bool {
        return false
    }

    func decode(_ type: Bool.Type) throws -> Bool {
        result.add(type: type, atPath: codingPath)
        return false
    }

    func decode(_ type: Int.Type) throws -> Int {
        result.add(type: type, atPath: codingPath)
        return 0
    }

    func decode(_ type: Double.Type) throws -> Double {
        result.add(type: type, atPath: codingPath)
        return 0
    }

    func decode(_ type: String.Type) throws -> String {
        result.add(type: type, atPath: codingPath)
        return "0"
    }

    func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
        let decoder = CodingKeyCollector(codingPath: codingPath, result: result)
        return try T(from: decoder)
    }
}

fileprivate struct CodingKeyCollectorKeyedDecoder<K>: KeyedDecodingContainerProtocol where K: CodingKey {
    typealias Key = K
    var allKeys: [K]
    var codingPath: [CodingKey]
    var result: CodingKeyCollectorResult

    init(codingPath: [CodingKey], result: CodingKeyCollectorResult) {
        self.codingPath = codingPath
        self.result = result
        self.allKeys = []
    }

    func contains(_ key: K) -> Bool {
        return true
    }

    func decodeNil(forKey key: K) throws -> Bool {
        if result.depth > codingPath.count {
            result.isOptional = true
            return false
        }
        return true
    }

    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: K) throws -> KeyedDecodingContainer<NestedKey>
        where NestedKey: CodingKey
    {
        let container = CodingKeyCollectorKeyedDecoder<NestedKey>(
            codingPath: codingPath + [key],
            result: result
        )
        return KeyedDecodingContainer(container)
    }

    func nestedUnkeyedContainer(forKey key: K) throws -> UnkeyedDecodingContainer {
        fatalError()
    }

    func superDecoder() throws -> Decoder {
        return CodingKeyCollector(codingPath: codingPath, result: result)
    }

    func superDecoder(forKey key: K) throws -> Decoder {
        return CodingKeyCollector(codingPath: codingPath + [key], result: result)
    }

    func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
        result.add(type: type, atPath: codingPath + [key])
        return false
    }

    func decode(_ type: Int.Type, forKey key: K) throws -> Int {
        result.add(type: type, atPath: codingPath + [key])
        return 0
    }

    func decode(_ type: Double.Type, forKey key: K) throws -> Double {
        result.add(type: type, atPath: codingPath + [key])
        return 0
    }

    func decode(_ type: String.Type, forKey key: K) throws -> String {
        result.add(type: type, atPath: codingPath + [key])
        return "0"
    }

    func decode<T>(_ type: T.Type, forKey key: K) throws -> T where T: Decodable {
        // restore query field map, for override
        if let custom = T.self as? AnyKeyStringDecodable.Type {
            result.add(type: type, atPath: codingPath + [key])
            return custom._keyStringFalse as! T
        } else {
            let decoder = CodingKeyCollector(codingPath: codingPath + [key], result: result)
            return try T(from: decoder)
        }
    }
}
