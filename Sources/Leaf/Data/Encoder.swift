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
        fatalError("unimplemented")
    }


}

