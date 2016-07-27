import Engine

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
    func index(request: HTTPRequest) throws -> HTTPResponseRepresentable

    /**
        Create a new instance.
     */
    func store(request: HTTPRequest) throws -> HTTPResponseRepresentable

    /**
        Show an instance.
     */
    func show(request: HTTPRequest, item: Item) throws -> HTTPResponseRepresentable

    /**
        Replaces an instance, deleting fields no longer presen in the request.
    */
    func replace(request: HTTPRequest, item: Item) throws -> HTTPResponseRepresentable

    /**
        Modify an instance, updating only the fields that are present in the request.
    */
    func modify(request: HTTPRequest, item: Item) throws -> HTTPResponseRepresentable

    /** 
        Delete an instance.
     */
    func destroy(request: HTTPRequest, item: Item) throws -> HTTPResponseRepresentable

    /**
        Delete all instances.
     */
    func destroy(request: HTTPRequest) throws -> HTTPResponseRepresentable

    /**
        Options for all instances.
    */
    func options(request: HTTPRequest) throws -> HTTPResponseRepresentable

    /**
        Options for a single instance.
    */
    func options(request: HTTPRequest, item: Item) throws -> HTTPResponseRepresentable
}

extension Resource {
    public func index(request: HTTPRequest) throws -> HTTPResponseRepresentable {
        throw Abort.notFound
    }

    public func store(request: HTTPRequest) throws -> HTTPResponseRepresentable {
        throw Abort.notFound
    }

    public func show(request: HTTPRequest, item: Item) throws -> HTTPResponseRepresentable {
        throw Abort.notFound
    }

    public func replace(request: HTTPRequest, item: Item) throws -> HTTPResponseRepresentable {
        throw Abort.notFound
    }

    public func modify(request: HTTPRequest, item: Item) throws -> HTTPResponseRepresentable {
        throw Abort.notFound
    }

    public func destroy(request: HTTPRequest, item: Item) throws -> HTTPResponseRepresentable {
        throw Abort.notFound
    }

    public func destroy(request: HTTPRequest) throws -> HTTPResponseRepresentable {
        throw Abort.notFound
    }

    public func options(request: HTTPRequest) throws -> HTTPResponseRepresentable {
        return HTTPResponse()
    }

    public func options(request: HTTPRequest, item: Item) throws -> HTTPResponseRepresentable {
        return HTTPResponse()
    }
}
