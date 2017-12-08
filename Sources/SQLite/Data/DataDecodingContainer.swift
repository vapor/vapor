internal final class DataDecodingContainer: SingleValueDecodingContainer {
    var codingPath: [CodingKey] {
        return decoder.codingPath
    }

    let decoder: SQLiteDataDecoder
    init(decoder: SQLiteDataDecoder) {
        self.decoder = decoder
    }

    func decodeNil() -> Bool {
        return decoder.data.isNull
    }

    func decode(_ type: Bool.Type) throws -> Bool {
        fatalError("unsupported")
    }

    func decode(_ type: Int.Type) throws -> Int {
        guard let int = decoder.data.fuzzyInt else {
            fatalError("todo")
        }
        return int
    }

    func decode(_ type: Int8.Type) throws -> Int8 {
        fatalError("unsupported")
    }

    func decode(_ type: Int16.Type) throws -> Int16 {
        fatalError("unsupported")
    }

    func decode(_ type: Int32.Type) throws -> Int32 {
        fatalError("unsupported")
    }

    func decode(_ type: Int64.Type) throws -> Int64 {
        fatalError("unsupported")
    }

    func decode(_ type: UInt.Type) throws -> UInt {
        fatalError("unsupported")
    }

    func decode(_ type: UInt8.Type) throws -> UInt8 {
        fatalError("unsupported")
    }

    func decode(_ type: UInt16.Type) throws -> UInt16 {
        fatalError("unsupported")
    }

    func decode(_ type: UInt32.Type) throws -> UInt32 {
        fatalError("unsupported")
    }

    func decode(_ type: UInt64.Type) throws -> UInt64 {
        fatalError("unsupported")
    }

    func decode(_ type: Float.Type) throws -> Float {
        fatalError("unsupported")
    }

    func decode(_ type: Double.Type) throws -> Double {
        guard let double = decoder.data.fuzzyDouble else {
            fatalError("todo")
        }
        return double
    }

    func decode(_ type: String.Type) throws -> String {
        guard let string = decoder.data.fuzzyString else {
            fatalError("todo")
        }
        return string
    }

    func decode<T: Decodable>(_ type: T.Type) throws -> T {
        return try T(from: decoder)
    }
}
