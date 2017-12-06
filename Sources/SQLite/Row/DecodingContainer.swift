internal final class DecodingContainer<K: CodingKey>:
    KeyedDecodingContainerProtocol,
    UnkeyedDecodingContainer,
    SingleValueDecodingContainer
{
    typealias Key = K

    var codingPath: [CodingKey] {
        return decoder.codingPath
    }

    var count: Int? {
        return nil
    }

    var isAtEnd: Bool {
        return false
    }

    var currentIndex: Int {
        return 0
    }

    var allKeys: [K] {
        return []
    }

    let decoder: SQLiteRowDecoder
    init(decoder: SQLiteRowDecoder) {
        self.decoder = decoder
    }

    func contains(_ key: K) -> Bool {
        let col = SQLiteColumn(name: key.stringValue)
        return decoder.row.fields.keys.contains(col)
    }

    func decodeNil(forKey key: K) throws -> Bool {
        return decoder.row[key.stringValue]?.isNull ?? true
    }

    func decode(_ type: Bool.Type, forKey key: K) throws -> Bool {
        fatalError("unimplemented")
    }

    func decode(_ type: Int.Type, forKey key: K) throws -> Int {
        guard let int = decoder.row[key.stringValue]?.fuzzyInt else {
            throw "No int found at key `\(key.stringValue)`"
        }

        return int
    }

    func decode(_ type: Int8.Type, forKey key: K) throws -> Int8 {
        fatalError("unimplemented")
    }

    func decode(_ type: Int16.Type, forKey key: K) throws -> Int16 {
        fatalError("unimplemented")
    }

    func decode(_ type: Int32.Type, forKey key: K) throws -> Int32 {
        fatalError("unimplemented")
    }

    func decode(_ type: Int64.Type, forKey key: K) throws -> Int64 {
        fatalError("unimplemented")
    }

    func decode(_ type: UInt.Type, forKey key: K) throws -> UInt {
        fatalError("unimplemented")
    }

    func decode(_ type: UInt8.Type, forKey key: K) throws -> UInt8 {
        fatalError("unimplemented")
    }

    func decode(_ type: UInt16.Type, forKey key: K) throws -> UInt16 {
        fatalError("unimplemented")
    }

    func decode(_ type: UInt32.Type, forKey key: K) throws -> UInt32 {
        fatalError("unimplemented")
    }

    func decode(_ type: UInt64.Type, forKey key: K) throws -> UInt64 {
        fatalError("unimplemented")
    }

    func decode(_ type: Float.Type, forKey key: K) throws -> Float {
        fatalError("unimplemented")
    }

    func decode(_ type: Double.Type, forKey key: K) throws -> Double {
        guard let double = decoder.row[key.stringValue]?.fuzzyDouble else {
            throw "No double found at key `\(key.stringValue)`"
        }

        return double
    }

    func decode(_ type: String.Type, forKey key: K) throws -> String {
        guard let string = decoder.row[key.stringValue]?.fuzzyString else {
            throw "No string found at key `\(key.stringValue)`"
        }

        return string
    }

    func decode<T: Decodable>(_ type: T.Type, forKey key: K) throws -> T {
        guard let data = decoder.row[key.stringValue] else {
            throw "no data at key"
        }

        let d = SQLiteDataDecoder(data: data)
        return try T(from: d)
    }

    func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type, forKey key: K) throws -> KeyedDecodingContainer<NestedKey> {
        fatalError("unimplemented")
    }

    func nestedUnkeyedContainer(forKey key: K) throws -> UnkeyedDecodingContainer {
        fatalError("unimplemented")
    }

    func superDecoder(forKey key: K) throws -> Decoder {
        fatalError("unimplemented")
    }

    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
        fatalError("unimplemented")
    }

    func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        fatalError("unimplemented")
    }

    func superDecoder() throws -> Decoder {
        fatalError("unimplemented")
    }

    func decodeNil() -> Bool {
        fatalError("unimplemented")
    }

    func decode(_ type: Bool.Type) throws -> Bool {
        fatalError("unimplemented")
    }

    func decode(_ type: Int.Type) throws -> Int {
        fatalError("unimplemented")
    }

    func decode(_ type: Int8.Type) throws -> Int8 {
        fatalError("unimplemented")
    }

    func decode(_ type: Int16.Type) throws -> Int16 {
        fatalError("unimplemented")
    }

    func decode(_ type: Int32.Type) throws -> Int32 {
        fatalError("unimplemented")
    }

    func decode(_ type: Int64.Type) throws -> Int64 {
        fatalError("unimplemented")
    }

    func decode(_ type: UInt.Type) throws -> UInt {
        fatalError("unimplemented")
    }

    func decode(_ type: UInt8.Type) throws -> UInt8 {
        fatalError("unimplemented")
    }

    func decode(_ type: UInt16.Type) throws -> UInt16 {
        fatalError("unimplemented")
    }

    func decode(_ type: UInt32.Type) throws -> UInt32 {
        fatalError("unimplemented")
    }

    func decode(_ type: UInt64.Type) throws -> UInt64 {
        fatalError("unimplemented")
    }

    func decode(_ type: Float.Type) throws -> Float {
        fatalError("unimplemented")
    }

    func decode(_ type: Double.Type) throws -> Double {
        fatalError("unimplemented")
    }

    func decode(_ type: String.Type) throws -> String {
        fatalError("unimplemented")
    }

    func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
        fatalError("unimplemented")
    }
}

extension SQLiteData {
    internal var fuzzyBool: Bool? {
        if let int = fuzzyInt {
            switch int {
            case 1:
                return true
            case 0:
                return false
            default:
                return nil
            }
        } else {
            return nil
        }
    }

    internal var fuzzyInt: Int? {
        switch self {
        case .integer(let int):
            return int
        case .text(let text):
            return Int(text)
        default:
            return nil
        }
    }

    internal var fuzzyString: String? {
        switch self {
        case .integer(let int):
            return int.description
        case .text(let text):
            return text
        default:
            return nil
        }
    }

    internal var fuzzyDouble: Double? {
        switch self {
        case .float(let double):
            return double
        case .text(let text):
            return Double(text)
        default:
            return nil
        }
    }
}

