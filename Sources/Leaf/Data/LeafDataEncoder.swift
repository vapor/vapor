import Async

public final class LeafDataEncoder: Encoder {
    public var codingPath: [CodingKey]
    public var userInfo: [CodingUserInfoKey: Any]

    var partialData: PartialLeafData
    public var context: LeafData {
        return partialData.context
    }

    public convenience init() {
        self.init(partialData: .init(), codingPath: [])
    }

    internal init(partialData: PartialLeafData, codingPath: [CodingKey]) {
        self.partialData = partialData
        self.codingPath = codingPath
        self.userInfo = [:]
    }

    /// See Encoder.container
    public func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        print("keyed container at \(codingPath)")
        let keyed = LeafDataKeyedEncoder<Key>(
            codingPath: codingPath,
            partialData: partialData
        )
        return KeyedEncodingContainer(keyed)
    }

    /// See Encoder.unkeyedContainer
    public func unkeyedContainer() -> UnkeyedEncodingContainer {
        print("unkeyed container at \(codingPath)")
        return LeafDataUnkeyedEncoder(
            codingPath: codingPath,
            partialData: partialData
        )
    }

    /// See Encoder.singleValueContainer
    public func singleValueContainer() -> SingleValueEncodingContainer {
        print("single value container at \(codingPath)")
        return LeafDataSingleEncoder(
            codingPath: codingPath,
            partialData: partialData
        )
    }

    /// Encode an encodable item to leaf data.
    public func encode<E>(_ encodable: E) throws -> LeafData
        where E: Encodable
    {
        try encodable.encode(to: self)
        let context = partialData.context
        partialData.context = .dictionary([:])
        return context
    }
}

public protocol FutureEncoder {
    mutating func encodeFuture<E>(_ future: Future<E>) throws
}

extension LeafDataEncoder: FutureEncoder {
    public func encodeFuture<E>(_ future: Future<E>) throws {
        let future: Future<LeafData> = future.map { any in
            guard let encodable = any as? Encodable else {
                throw "not encodable!"
            }

            let encoder = LeafDataEncoder.init(
                partialData: self.partialData,
                codingPath: self.codingPath
            )
            try encodable.encode(to: encoder)
            return encoder.context
        }
        
        self.partialData.set(to: .future(future), at: codingPath)
    }
}

extension Future: Codable {
    public func encode(to encoder: Encoder) throws {
        guard var encoder = encoder as? FutureEncoder else {
            throw "need a future encoder"
        }

        try encoder.encodeFuture(self)
    }

    public convenience init(from decoder: Decoder) throws {
        fatalError("not implemented")
    }
}
