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
    func index(request: HTTPRequest) throws -> ResponseRepresentable

    /**
        Create a new instance.
     */
    func store(request: HTTPRequest) throws -> ResponseRepresentable

    /**
        Show an instance.
     */
    func show(request: HTTPRequest, item: Item) throws -> ResponseRepresentable

    /**
        Replaces an instance, deleting fields no longer presen in the request.
    */
    func replace(request: HTTPRequest, item: Item) throws -> ResponseRepresentable

    /**
        Modify an instance, updating only the fields that are present in the request.
    */
    func modify(request: HTTPRequest, item: Item) throws -> ResponseRepresentable

    /** 
        Delete an instance.
     */
    func destroy(request: HTTPRequest, item: Item) throws -> ResponseRepresentable

    /**
        Delete all instances.
     */
    func destroy(request: HTTPRequest) throws -> ResponseRepresentable

    /**
        Options for all instances.
    */
    func options(request: HTTPRequest) throws -> ResponseRepresentable

    /**
        Options for a single instance.
    */
    func options(request: HTTPRequest, item: Item) throws -> ResponseRepresentable
}

extension ResourceController {
    public func index(request: HTTPRequest) throws -> ResponseRepresentable {
        throw Abort.notFound
    }

    public func store(request: HTTPRequest) throws -> ResponseRepresentable {
        throw Abort.notFound
    }

    public func show(request: HTTPRequest, item: Item) throws -> ResponseRepresentable {
        throw Abort.notFound
    }

    public func replace(request: HTTPRequest, item: Item) throws -> ResponseRepresentable {
        throw Abort.notFound
    }

    public func modify(request: HTTPRequest, item: Item) throws -> ResponseRepresentable {
        throw Abort.notFound
    }

    public func destroy(request: HTTPRequest, item: Item) throws -> ResponseRepresentable {
        throw Abort.notFound
    }

    public func destroy(request: HTTPRequest) throws -> ResponseRepresentable {
        throw Abort.notFound
    }

    public func options(request: HTTPRequest) throws -> ResponseRepresentable {
        return HTTPResponse()
    }

    public func options(request: HTTPRequest, item: Item) throws -> ResponseRepresentable {
        return HTTPResponse()
    }
}
