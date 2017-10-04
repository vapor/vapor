/// A SQL serializer.
public protocol SQLSerializer {
    associatedtype E: Model
    init(_ query: Query<E>)
    func serialize() throws -> (String, [Node])
}
