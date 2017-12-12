import Foundation

/// Maps KeyPath to [CodingKey] on Decodable types.
extension Decodable {
    public static func codingPath(forKey keyPath: AnyKeyPath) -> [CodingKey] {
        var depth = 0
        a: while true {
            defer { depth += 1 }
            var progress = 0

            b: while true {
                defer { progress += 1 }
                let result = KeyStringDecoderResult(progress: progress, depth: depth)
                let decoder = KeyStringDecoder(codingPath: [], result: result)

                let decoded = try! Self(from: decoder)
                guard let codingPath = result.codingPath else {
                    // no more values are being set at this depth
                    break b
                }

                if isTruthy(decoded[keyPath: keyPath]) {
                    return codingPath
                }
            }
        }
    }
}

private func isTruthy(_ any: Any?) -> Bool {
    switch any! {
    case let bool as Bool: return bool
    case let int as Int: return int == 1
    case let string as String: return string == "1"
    case let double as Double: return double == 1
    case let custom as KeyStringDecodable: return type(of: custom).keyStringIsTrue(custom)
    case let opt as Optional<Any>:
        switch opt {
        case .none: return false
        case .some(let w): return isTruthy(w)
        }
    default: fatalError("unsupported type: \(type(of: any))")
    }
}

internal final class KeyStringDecoderResult {
    var codingPath: [CodingKey]?
    var progress: Int
    var current: Int
    var depth: Int
    var cycle: Bool {
        defer { current += 1 }
        return current == progress
    }

    init(progress: Int, depth: Int) {
        codingPath = nil
        current = 0
        self.depth = depth
        self.progress = progress
    }
}

internal final class KeyStringDecoder: Decoder {
    var codingPath: [CodingKey]
    var result: KeyStringDecoderResult
    var userInfo: [CodingUserInfoKey: Any]

    init(codingPath: [CodingKey], result: KeyStringDecoderResult) {
        self.codingPath = codingPath
        self.result = result
        userInfo = [:]
    }

    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
        let container = KeyStringKeyedDecoder<Key>(codingPath: codingPath, result: result)
        return KeyedDecodingContainer(container)
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        fatalError("key string mapping arrays is not yet supported")
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        return KeyStringSingleValueDecoder(codingPath: codingPath, result: result)
    }
}

internal struct KeyStringSingleValueDecoder: SingleValueDecodingContainer {
    var codingPath: [CodingKey]
    var result: KeyStringDecoderResult

    init(codingPath: [CodingKey], result: KeyStringDecoderResult) {
        self.codingPath = codingPath
        self.result = result
    }

    func decodeNil() -> Bool {
        return false
    }

    func decode(_ type: Bool.Type) throws -> Bool {
        if result.cycle {
            result.codingPath = codingPath
            return true
        }
        return false
    }

    func decode(_ type: Int.Type) throws -> Int {
        if result.cycle {
            result.codingPath = codingPath
            return 1
        }
        return 0
    }

    func decode(_ type: Double.Type) throws -> Double {
        if result.cycle {
            result.codingPath = codingPath
            return 1
        }
        return 0
    }

    func decode(_ type: String.Type) throws -> String {
        if result.cycle {
            result.codingPath = codingPath
            return "1"
        }
        return "0"
    }

    func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
        let decoder = KeyStringDecoder(codingPath: codingPath, result: result)
        return try T(from: decoder)
    }
}

public protocol KeyStringDecodable {
    static var keyStringTrue: Any { get }
    static var keyStringFalse: Any { get }
    static func keyStringIsTrue(_ any: Any) -> Bool
}

let _false = UUID()
let _true = UUID()

extension UUID: KeyStringDecodable {
    public static var keyStringTrue: Any { return _true }
    public static var keyStringFalse: Any { return _false }
    public static func keyStringIsTrue(_ any: Any) -> Bool {
        return (any as! UUID) == _true
    }
}

let _falsedate = Date(timeIntervalSince1970: 0)
let _truedate = Date(timeIntervalSince1970: 1)

extension Date: KeyStringDecodable {
    public static var keyStringTrue: Any { return _truedate }
    public static var keyStringFalse: Any { return _falsedate }
    public static func keyStringIsTrue(_ any: Any) -> Bool {
        return (any as! Date) == _truedate
    }
}

internal struct KeyStringKeyedDecoder<K>: KeyedDecodingContainerProtocol where K: CodingKey {
    typealias Key = K
    var allKeys: [K]
    var codingPath: [CodingKey]
    var result: KeyStringDecoderResult

    init(codingPath: [CodingKey], result: KeyStringDecoderResult) {
        self.codingPath = codingPath
        self.result = result
        self.allKeys = []
    }

    func contains(_ key: K) -> Bool {
        return true
    }

    func decodeNil(forKey key: K) throws -> Bool {
        if result.depth > codingPath.count {
            return false
        }
        return true
    }

    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: K) throws -> KeyedDecodingContainer<NestedKey>
        where NestedKey: CodingKey
    {
        let container = KeyStringKeyedDecoder<NestedKey>(codingPath: codingPath + [key], result: result)
        return KeyedDecodingContainer(container)
    }

    func nestedUnkeyedContainer(forKey key: K) throws -> UnkeyedDecodingContainer {
        fatalError()
    }

    func superDecoder() throws -> Decoder {
        return KeyStringDecoder(codingPath: codingPath, result: result)
    }

    func superDecoder(forKey key: K) throws -> Decoder {
        return KeyStringDecoder(codingPath: codingPath + [key], result: result)
    }

    func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
        if result.cycle {
            result.codingPath = codingPath + [key]
            return true
        }
        return false
    }

    func decode(_ type: Int.Type, forKey key: K) throws -> Int {
        if result.cycle {
            result.codingPath = codingPath + [key]
            return 1
        }
        return 0
    }

    func decode(_ type: Double.Type, forKey key: K) throws -> Double {
        if result.cycle {
            result.codingPath = codingPath + [key]
            return 1
        }
        return 0
    }

    func decode(_ type: String.Type, forKey key: K) throws -> String {
        if result.cycle {
            result.codingPath = codingPath + [key]
            return "1"
        }
        return "0"
    }

    func decode<T>(_ type: T.Type, forKey key: K) throws -> T where T : Decodable {
        // restore query field map, for override
        if let custom = T.self as? KeyStringDecodable.Type {
            if result.cycle {
                result.codingPath = codingPath + [key]
                return custom.keyStringTrue as! T
            } else {
                return custom.keyStringFalse as! T
            }
        } else {
            let decoder = KeyStringDecoder(codingPath: codingPath + [key], result: result)
            return try T(from: decoder)
        }
    }
}
