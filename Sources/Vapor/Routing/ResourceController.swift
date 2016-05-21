/**
    Organize your routing logic with a conformance of
    `ResourceController`. Controls group related route logic into
    a single protocol that, by default, conforms to standard
    CRUD operations.
*/
public protocol ResourceController {
    associatedtype Item: StringInitializable

    /**
        Display many instances
     */
    func index(_ request: Request) throws -> ResponseRepresentable

    /**
        Create a new instance.
     */
    func store(_ request: Request) throws -> ResponseRepresentable

    /**
        Show an instance.
     */
    func show(_ request: Request, item: Item) throws -> ResponseRepresentable

    /**
        Update an instance.
     */
    func update(_ request: Request, item: Item) throws -> ResponseRepresentable

    /** 
        Delete an instance.
     */
    func destroy(_ request: Request, item: Item) throws -> ResponseRepresentable

    /**
        Delete all instances.
     */
    func destroyAll(_ request: Request) throws -> ResponseRepresentable
}

extension ResourceController {

    /**
        Display many instances
     */
    public func index(_ request: Request) throws -> ResponseRepresentable {
        throw Abort.notFound
    }

    /**
        Create a new instance.
     */
    public func store(_ request: Request) throws -> ResponseRepresentable {
        throw Abort.notFound
    }

    /**
        Show an instance.
     */
    public func show(_ request: Request, item: Item) throws -> ResponseRepresentable {
        throw Abort.notFound
    }

    /**
        Update an instance.
     */
    public func update(_ request: Request, item: Item) throws -> ResponseRepresentable {
        throw Abort.notFound
    }

    /**
        Delete an instance.
     */
    public func destroy(_ request: Request, item: Item) throws -> ResponseRepresentable {
        throw Abort.notFound
    }

    /**
        Delete all instances.
     */
    public func destroyAll(_ request: Request) throws -> ResponseRepresentable {
        throw Abort.notFound
    }
}
