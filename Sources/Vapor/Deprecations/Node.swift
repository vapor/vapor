import Mapper

@available(*, deprecated, message: "Node has been renamed to Map (import Mapper)")
public enum Node { }

@available(*, deprecated, message: "NodeRepresentable has been renamed to MapRepresentable (import Mapper)")
public protocol NodeRepresentable { }

@available(*, deprecated, message: "NodeInitializable has been renamed to MapInitializable (import Mapper)")
public protocol NodeInitializable { }

@available(*, deprecated, message: "NodeConvertible has been renamed to MapConvertible (import Mapper)")
public protocol NodeConvertible { }

extension Keyed {
    @available(*, deprecated, message: "Use set(..., to: ...) or set(dot: ..., to: ...)")
    public func set<T>(_ path: String, _ value: T) throws {
        fatalError("Use set(..., to: ...) or set(dot: ..., to: ...)")
    }
}
