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
    func index(request: Request) throws -> ResponseRepresentable

    /**
        Create a new instance.
     */
    func store(request: Request) throws -> ResponseRepresentable

    /**
        Show an instance.
     */
    func show(request: Request, item: Item) throws -> ResponseRepresentable

    /**
        Update an instance.
     */
    func update(request: Request, item: Item) throws -> ResponseRepresentable

    /**
        Modify an instance (only the fields that are present in the request)
     */
    func modify(request: Request, item: Item) throws -> ResponseRepresentable

    /** 
        Delete an instance.
     */
    func destroy(request: Request, item: Item) throws -> ResponseRepresentable

    /**
        Delete all instances.
     */
    func destroy(request: Request) throws -> ResponseRepresentable

    /**
        Options for all instances.
    */
    func options(request: Request) throws -> ResponseRepresentable

    /**
        Options for a single instance.
    */
    func options(request: Request, item: Item) throws -> ResponseRepresentable
}

extension ResourceController {

    /**
        Display many instances
     */
    public func index(request: Request) throws -> ResponseRepresentable {
        throw Abort.notFound
    }

    /**
        Create a new instance.
     */
    public func store(request: Request) throws -> ResponseRepresentable {
        throw Abort.notFound
    }

    /**
        Show an instance.
     */
    public func show(request: Request, item: Item) throws -> ResponseRepresentable {
        throw Abort.notFound
    }

    /**
        Update an instance.
     */
    public func update(request: Request, item: Item) throws -> ResponseRepresentable {
        throw Abort.notFound
    }

    /**
        Modify an instance (only the fields that are present in the request)
     */
    public func modify(request: Request, item: Item) throws -> ResponseRepresentable {
        throw Abort.notFound
    }

    /**
        Delete an instance.
     */
    public func destroy(request: Request, item: Item) throws -> ResponseRepresentable {
        throw Abort.notFound
    }

    /**
        Delete all instances.
     */
    public func destroy(request: Request) throws -> ResponseRepresentable {
        throw Abort.notFound
    }

    /**
        Options for all instances.
    */
    public func options(request: Request) throws -> ResponseRepresentable {
        return Response(body: [])
    }

    /**
        Options for a single instance.
    */
    public func options(request: Request, item: Item) throws -> ResponseRepresentable {
        return Response(body: [])
    }
}
