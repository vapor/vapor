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
    func index(request: HTTP.Request) throws -> ResponseRepresentable

    /**
        Create a new instance.
     */
    func store(request: HTTP.Request) throws -> ResponseRepresentable

    /**
        Show an instance.
     */
    func show(request: HTTP.Request, item: Item) throws -> ResponseRepresentable

    /**
        Replaces an instance, deleting fields no longer presen in the request.
    */
    func replace(request: HTTP.Request, item: Item) throws -> ResponseRepresentable

    /**
        Modify an instance, updating only the fields that are present in the request.
    */
    func modify(request: HTTP.Request, item: Item) throws -> ResponseRepresentable

    /** 
        Delete an instance.
     */
    func destroy(request: HTTP.Request, item: Item) throws -> ResponseRepresentable

    /**
        Delete all instances.
     */
    func destroy(request: HTTP.Request) throws -> ResponseRepresentable

    /**
        Options for all instances.
    */
    func options(request: HTTP.Request) throws -> ResponseRepresentable

    /**
        Options for a single instance.
    */
    func options(request: HTTP.Request, item: Item) throws -> ResponseRepresentable
}

extension ResourceController {
    public func index(request: HTTP.Request) throws -> ResponseRepresentable {
        throw Abort.notFound
    }

    public func store(request: HTTP.Request) throws -> ResponseRepresentable {
        throw Abort.notFound
    }

    public func show(request: HTTP.Request, item: Item) throws -> ResponseRepresentable {
        throw Abort.notFound
    }

    public func replace(request: HTTP.Request, item: Item) throws -> ResponseRepresentable {
        throw Abort.notFound
    }

    public func modify(request: HTTP.Request, item: Item) throws -> ResponseRepresentable {
        throw Abort.notFound
    }

    public func destroy(request: HTTP.Request, item: Item) throws -> ResponseRepresentable {
        throw Abort.notFound
    }

    public func destroy(request: HTTP.Request) throws -> ResponseRepresentable {
        throw Abort.notFound
    }

    public func options(request: HTTP.Request) throws -> ResponseRepresentable {
        return HTTP.Response()
    }

    public func options(request: HTTP.Request, item: Item) throws -> ResponseRepresentable {
        return HTTP.Response()
    }
}
