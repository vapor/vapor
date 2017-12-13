internal final class DataEncodingContainer: SingleValueEncodingContainer {
    var codingPath: [CodingKey] {
        return encoder.codingPath
    }

    let encoder: SQLiteDataEncoder
    init(encoder: SQLiteDataEncoder) {
        self.encoder = encoder
    }

    func encodeNil() throws {
        encoder.data = .null
    }

    func encode(_ value: Bool) throws {
        encoder.data = .integer(value ? 1 : 0)
    }

    func encode(_ value: Int) throws {
        encoder.data = .integer(value)
    }

    func encode(_ value: Int8) throws {
        try encode(Int(value))
    }

    func encode(_ value: Int16) throws {
        try encode(Int(value))
    }

    func encode(_ value: Int32) throws {
        try encode(Int(value))
    }

    func encode(_ value: Int64) throws {
        try encode(Int(value))
    }

    func encode(_ value: UInt) throws {
        try encode(Int(value))
    }

    func encode(_ value: UInt8) throws {
        try encode(Int(value))
    }

    func encode(_ value: UInt16) throws {
        try encode(Int(value))
    }

    func encode(_ value: UInt32) throws {
        try encode(Int(value))
    }

    func encode(_ value: UInt64) throws {
        try encode(Int(value))
    }

    func encode(_ value: Float) throws {
        try encode(Double(value))
    }

    func encode(_ value: Double) throws {
        encoder.data = .float(value)
    }

    func encode(_ value: String) throws {
        encoder.data = .text(value)
    }

    func encode<T: Encodable>(_ value: T) throws {
        try value.encode(to: encoder)
    }
}
