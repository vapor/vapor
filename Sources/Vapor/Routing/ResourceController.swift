/**
    Organize your routing logic with a conformance of
    `ResourceController`. Controls group related route logic into
    a single protocol that, by default, conforms to standard
    CRUD operations.
*/
public protocol ResourceController {
    associatedtype Item: StringInitializable
    /// Display many instances
    func index(request: Request) throws -> ResponseRepresentable

    /// Create a new instance.
    func store(request: Request) throws -> ResponseRepresentable

    /// Show an instance.
    func show(request: Request, item: Item) throws -> ResponseRepresentable

    /// Update an instance.
    func update(request: Request, item: Item) throws -> ResponseRepresentable

    /// Delete an instance.
    func destroy(request: Request, item: Item) throws -> ResponseRepresentable
}

extension ResourceController {
    /// Display many instances
    public func index(request: Request) throws -> ResponseRepresentable {
        throw Abort.notFound
    }

    /// Create a new instance.
    public func store(request: Request) throws -> ResponseRepresentable {
        throw Abort.notFound
    }

    /// Show an instance.
    public func show(request: Request, item: Item) throws -> ResponseRepresentable {
        throw Abort.notFound
    }

    /// Update an instance.
    public func update(request: Request, item: Item) throws -> ResponseRepresentable {
        throw Abort.notFound
    }

    /// Delete an instance.
    public func destroy(request: Request, item: Item) throws -> ResponseRepresentable {
        throw Abort.notFound
    }
}
