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
    func post(request: Request) throws -> ResponseRepresentable

    /**
        Show an instance.
     */
    func get(request: Request, item: Item) throws -> ResponseRepresentable

    /**
        Replaces an instance, deleting fields no longer presen in the request.
    */
    func put(request: Request, item: Item) throws -> ResponseRepresentable

    /**
        Modify an instance, updating only the fields that are present in the request.
    */
    func patch(request: Request, item: Item) throws -> ResponseRepresentable

    /** 
        Delete an instance.
     */
    func delete(request: Request, item: Item) throws -> ResponseRepresentable

    /**
        Delete all instances.
     */
    func delete(request: Request) throws -> ResponseRepresentable

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
    public func index(request: Request) throws -> ResponseRepresentable {
        throw Abort.notFound
    }

    public func post(request: Request) throws -> ResponseRepresentable {
        throw Abort.notFound
    }

    public func get(request: Request, item: Item) throws -> ResponseRepresentable {
        throw Abort.notFound
    }

    public func put(request: Request, item: Item) throws -> ResponseRepresentable {
        throw Abort.notFound
    }

    public func patch(request: Request, item: Item) throws -> ResponseRepresentable {
        throw Abort.notFound
    }

    public func delete(request: Request, item: Item) throws -> ResponseRepresentable {
        throw Abort.notFound
    }

    public func delete(request: Request) throws -> ResponseRepresentable {
        throw Abort.notFound
    }

    public func options(request: Request) throws -> ResponseRepresentable {
        return Response()
    }

    public func options(request: Request, item: Item) throws -> ResponseRepresentable {
        return Response()
    }
}
