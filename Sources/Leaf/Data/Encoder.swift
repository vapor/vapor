import Async

public protocol FutureEncoder {
    mutating func encode<E>(_ future: Future<E>) throws
}

public final class ContextEncoder: Encoder {
    public var codingPath: [CodingKey]
    public var userInfo: [CodingUserInfoKey: Any]

    public var context: Context

    public init() {
        self.codingPath = []
        self.userInfo = [:]
        self.context = .dictionary([:])
    }


    public func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        return KeyedEncodingContainer(ContextContainer(encoder: self))
    }

    public func unkeyedContainer() -> UnkeyedEncodingContainer {
        fatalError("unimplemented")
    }

    public func singleValueContainer() -> SingleValueEncodingContainer {
        return ContextContainer<NoKey>(encoder: self)
    }
}

public struct NoKey: CodingKey {
    public var stringValue: String
    public var intValue: Int?

    public init?(stringValue: String) {
        self.stringValue = ""
    }

    public init?(intValue: Int) {
        self.stringValue = ""
        self.intValue = nil
    }
}


