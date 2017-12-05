/// MARK: Model
import Core
import Fluent

extension Toy {
    /// See KeyStringMappable.keyStringMap
    static var keyStringMap: KeyStringMap {
        return [
            key(\.id): "id",
            key(\.name): "name",
            key(\.pets): "pets",
        ]
    }
}
extension TestUser {
    /// See KeyStringMappable.keyStringMap
    static var keyStringMap: KeyStringMap {
        return [
            key(\.id): "id",
            key(\.name): "name",
            key(\.age): "age",
        ]
    }
}
extension Pet {
    /// See KeyStringMappable.keyStringMap
    static var keyStringMap: KeyStringMap {
        return [
            key(\.id): "id",
            key(\.name): "name",
            key(\.ownerID): "ownerID",
            key(\.owner): "owner",
            key(\.toys): "toys",
        ]
    }
}
extension User {
    /// See KeyStringMappable.keyStringMap
    static var keyStringMap: KeyStringMap {
        return [
            key(\.id): "id",
            key(\.name): "name",
            key(\.age): "age",
            key(\.pets): "pets",
        ]
    }
}
