import Core

internal struct ContextContainer<K: CodingKey>:
    KeyedEncodingContainerProtocol,
    UnkeyedEncodingContainer,
    SingleValueEncodingContainer,
    FutureEncoder
{
    typealias Key = K

    var count: Int

    var encoder: ContextEncoder
    var codingPath: [CodingKey] {
        get { return encoder.codingPath }
        set { encoder.codingPath = newValue }
    }

    public init(encoder: ContextEncoder) {
        self.encoder = encoder
        self.count = 0
    }

    mutating func encodeNil() throws {
        fatalError("unimplemented")
    }

    mutating func nestedContainer<NestedKey: CodingKey>(
        keyedBy keyType: NestedKey.Type
    ) -> KeyedEncodingContainer<NestedKey> {
        fatalError("unimplemented")
    }

    mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        fatalError("unimplemented")
    }

    mutating func superEncoder() -> Encoder {
        fatalError("unimplemented")
    }

    mutating func encodeNil(forKey key: K) throws {
        fatalError("unimplemented")
    }

    mutating func nestedContainer<NestedKey: CodingKey>(
        keyedBy keyType: NestedKey.Type, forKey key: K
    ) -> KeyedEncodingContainer<NestedKey> {
        fatalError("unimplemented")
    }

    mutating func nestedUnkeyedContainer(forKey key: K) -> UnkeyedEncodingContainer {
        fatalError("unimplemented")
    }

    mutating func superEncoder(forKey key: K) -> Encoder {
        fatalError("unimplemented")
    }

    mutating func encode(_ value: Bool) throws {
        fatalError("unimplemented")
    }

    mutating func encode(_ value: Bool, forKey key: K) throws {
        fatalError("unimplemented")
    }

    mutating func encode(_ value: Int) throws {
        fatalError("unimplemented")
    }

    mutating func encode(_ value: Int8) throws {
        fatalError("unimplemented")
    }

    mutating func encode(_ value: Int16) throws {
        fatalError("unimplemented")
    }

    mutating func encode(_ value: Int32) throws {
        fatalError("unimplemented")
    }

    mutating func encode(_ value: Int64) throws {
        fatalError("unimplemented")
    }

    mutating func encode(_ value: UInt) throws {
        fatalError("unimplemented")
    }

    mutating func encode(_ value: UInt8) throws {
        fatalError("unimplemented")
    }

    mutating func encode(_ value: UInt16) throws {
        fatalError("unimplemented")
    }

    mutating func encode(_ value: UInt32) throws {
        fatalError("unimplemented")
    }

    mutating func encode(_ value: UInt64) throws {
        fatalError("unimplemented")
    }

    mutating func encode(_ value: Float) throws {
        fatalError("unimplemented")
    }

    mutating func encode(_ value: Double) throws {
        fatalError("unimplemented")
    }

    mutating func encode(_ value: String) throws {
        fatalError("unimplemented")
    }

    mutating func encode<T: Encodable>(_ value: T) throws {
        fatalError("unimplemented")
    }

    mutating func encode(_ value: Int, forKey key: K) throws {
        set(.int(value), forKey: key)
    }

    mutating func encode(_ value: Int8, forKey key: K) throws {
        fatalError("unimplemented")
    }

    mutating func encode(_ value: Int16, forKey key: K) throws {
        fatalError("unimplemented")
    }

    mutating func encode(_ value: Int32, forKey key: K) throws {
        fatalError("unimplemented")
    }

    mutating func encode(_ value: Int64, forKey key: K) throws {
        fatalError("unimplemented")
    }

    mutating func encode(_ value: UInt, forKey key: K) throws {
        fatalError("unimplemented")
    }

    mutating func encode(_ value: UInt8, forKey key: K) throws {
        fatalError("unimplemented")
    }

    mutating func encode(_ value: UInt16, forKey key: K) throws {
        fatalError("unimplemented")
    }

    mutating func encode(_ value: UInt32, forKey key: K) throws {
        fatalError("unimplemented")
    }

    mutating func encode(_ value: UInt64, forKey key: K) throws {
        fatalError("unimplemented")
    }

    mutating func encode(_ value: Float, forKey key: K) throws {
        fatalError("unimplemented")
    }

    mutating func encode(_ value: Double, forKey key: K) throws {
        fatalError("unimplemented")
    }


    mutating func encode<E>(_ future: Future<E>) throws {
        let promise = Promise(Context.self)

        future.then { item in
            if let encodable = item as? Encodable {
                let encoder = ContextEncoder()
                try! encodable.encode(to: encoder)
                promise.complete(encoder.context)
            } else {
                print("fail")
                promise.fail("could not encode")
            }
        }.catch { error in
            print("fail")
            promise.fail(error)
        }

        set(.future(promise.future))
    }

    mutating func encode(_ value: String, forKey key: K) throws {
        set(.string(value), forKey: key)
    }

    mutating func encode<T: Encodable>(_ value: T, forKey key: K) throws {
        codingPath.append(key)
        try value.encode(to: encoder)
        _ = codingPath.popLast()
    }

    mutating func set(_ context: inout Context, to value: Context?, at path: [CodingKey]) {
        var child: Context?
        switch path.count {
        case 1:
            child = value
        case 2...:
            child = context.dictionary?[path[0].stringValue] ?? Context.dictionary([:])
            set(&child!, to: value, at: Array(path[1...]))
        default: return
        }

        if case .dictionary(var dict) = context {
            dict[path[0].stringValue] = child
            context = .dictionary(dict)
        } else if let child = child {
            context = .dictionary([
                path[0].stringValue: child
            ])
        }
    }

    /// Returns the value, if one at from the given path.
    public func get(_ context: Context, at path: [CodingKey]) -> Context? {
        var child = context

        for seg in path {
            guard let c = child.dictionary?[seg.stringValue] else {
                return nil
            }
            child = c
        }

        return child
    }

    mutating func set(_ value: Context) {
        set(&encoder.context, to: value, at: encoder.codingPath)
    }

    mutating func set(_ value: Context, forKey key: K) {
        set(&encoder.context, to: value, at: encoder.codingPath + [key])
    }
}
