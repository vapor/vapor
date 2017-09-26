/// A SQL serializer.
public protocol SQLSerializer {
    associatedtype E: Entity
    init(_ query: Query<E>)
    func serialize() throws -> (String, [Node])
}
