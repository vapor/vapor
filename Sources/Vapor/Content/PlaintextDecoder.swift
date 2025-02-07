import NIOCore
import NIOHTTP1

/// Decodes data as plaintext, utf8.
public struct PlaintextDecoder: ContentDecoder {
    public init() {}

    /// `ContentDecoder` conformance.
    public func decode<D>(_ decodable: D.Type, from body: ByteBuffer, headers: HTTPHeaders) throws -> D
    where D: Decodable {
        try self.decode(D.self, from: body, headers: headers, userInfo: [:])
    }

    /// `ContentDecoder` conformance.
    public func decode<D>(_ decodable: D.Type, from body: ByteBuffer, headers: HTTPHeaders, userInfo: [CodingUserInfoKey: Sendable]) throws
        -> D
    where D: Decodable {
        let string = body.getString(at: body.readerIndex, length: body.readableBytes)

        return try D(from: _PlaintextDecoder(plaintext: string, userInfo: userInfo))
    }
}

// MARK: Private

private final class _PlaintextDecoder: Decoder, SingleValueDecodingContainer {
    let codingPath: [CodingKey] = []
    let userInfo: [CodingUserInfoKey: Any]
    let plaintext: String?

    init(plaintext: String?, userInfo: [CodingUserInfoKey: Sendable] = [:]) {
        self.plaintext = plaintext
        self.userInfo = userInfo
    }

    func container<Key: CodingKey>(keyedBy: Key.Type) throws -> KeyedDecodingContainer<Key> {
        throw DecodingError.typeMismatch(
            [String: Decodable].self,
            .init(codingPath: self.codingPath, debugDescription: "Plaintext decoding does not support dictionaries."))
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        throw DecodingError.typeMismatch(
            [String].self, .init(codingPath: self.codingPath, debugDescription: "Plaintext decoding does not support arrays."))
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer { self }

    func decodeNil() -> Bool { self.plaintext?.isEmpty ?? true }

    func losslessDecode<L: LosslessStringConvertible>(_: L.Type) throws -> L {
        guard let value = self.plaintext else {
            throw DecodingError.valueNotFound(
                L.self, .init(codingPath: self.codingPath, debugDescription: "Missing value of type \(L.self)"))
        }
        guard let result = L.init(value) else {
            throw DecodingError.dataCorruptedError(in: self, debugDescription: "Could not decode \(L.self) from \"\(value)\"")
        }
        return result
    }

    func decode(_ type: String.Type) throws -> String { self.plaintext ?? "" }

    // N.B.: Implementing the individual "primitive" coding methods on a container rather than forwarding through
    // each type's Codable implementation yields substantial speedups.
    func decode(_: Bool.Type) throws -> Bool { try self.losslessDecode(Bool.self) }
    func decode(_: Double.Type) throws -> Double { try self.losslessDecode(Double.self) }
    func decode(_: Float.Type) throws -> Float { try self.losslessDecode(Float.self) }
    func decode(_: Int.Type) throws -> Int { try self.losslessDecode(Int.self) }
    func decode(_: Int8.Type) throws -> Int8 { try self.losslessDecode(Int8.self) }
    func decode(_: Int16.Type) throws -> Int16 { try self.losslessDecode(Int16.self) }
    func decode(_: Int32.Type) throws -> Int32 { try self.losslessDecode(Int32.self) }
    func decode(_: Int64.Type) throws -> Int64 { try self.losslessDecode(Int64.self) }
    func decode(_: UInt.Type) throws -> UInt { try self.losslessDecode(UInt.self) }
    func decode(_: UInt8.Type) throws -> UInt8 { try self.losslessDecode(UInt8.self) }
    func decode(_: UInt16.Type) throws -> UInt16 { try self.losslessDecode(UInt16.self) }
    func decode(_: UInt32.Type) throws -> UInt32 { try self.losslessDecode(UInt32.self) }
    func decode(_: UInt64.Type) throws -> UInt64 { try self.losslessDecode(UInt64.self) }

    func decode<T>(_: T.Type) throws -> T where T: Decodable {
        if let convertible = T.self as? LosslessStringConvertible.Type {
            return try self.losslessDecode(convertible) as! T
        }
        throw DecodingError.typeMismatch(
            T.self, .init(codingPath: self.codingPath, debugDescription: "Plaintext decoding does not support complex types."))
    }
}
