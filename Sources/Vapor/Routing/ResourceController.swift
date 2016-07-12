import protocol Engine.HTTPResponseRepresentable

/**
    Organize your routing logic with a conformance of
    `ResourceController`. Controls group related route logic into
    a single protocol that, by default, conforms to standard
    CRUD operations.
*/
public protocol Resource {
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
        Replaces an instance, deleting fields no longer presen in the request.
    */
    func replace(request: Request, item: Item) throws -> ResponseRepresentable

    /**
        Modify an instance, updating only the fields that are present in the request.
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

extension Resource {
    public func index(request: Request) throws -> ResponseRepresentable {
        throw Abort.notFound
    }

    public func store(request: Request) throws -> ResponseRepresentable {
        throw Abort.notFound
    }

    public func show(request: Request, item: Item) throws -> ResponseRepresentable {
        throw Abort.notFound
    }

    public func replace(request: Request, item: Item) throws -> ResponseRepresentable {
        throw Abort.notFound
    }

    public func modify(request: Request, item: Item) throws -> ResponseRepresentable {
        throw Abort.notFound
    }

    public func destroy(request: Request, item: Item) throws -> ResponseRepresentable {
        throw Abort.notFound
    }

    public func destroy(request: Request) throws -> ResponseRepresentable {
        throw Abort.notFound
    }

    public func options(request: Request) throws -> ResponseRepresentable {
        return Response()
    }

    public func options(request: Request, item: Item) throws -> ResponseRepresentable {
        return Response()
    }
}
