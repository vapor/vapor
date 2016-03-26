/**
    Organize your routing logic with a conformance of
    `ResourceController`. Controls group related route logic into
    a single protocol that, by default, conforms to standard
    CRUD operations.
*/
public protocol ResourceController {
    /// Display many instances
    func index(request: Request) throws -> ResponseConvertible

    /// Create a new instance.
    func store(request: Request) throws -> ResponseConvertible

    /// Show an instance.
    func show(request: Request) throws -> ResponseConvertible

    /// Update an instance.
    func update(request: Request) throws -> ResponseConvertible

    /// Delete an instance.
    func destroy(request: Request) throws -> ResponseConvertible
}

extension ResourceController {
    /// Display many instances
    public func index(request: Request) throws -> ResponseConvertible {
        throw Abort.NotFound
    }
    
    /// Create a new instance.
    public func store(request: Request) throws -> ResponseConvertible {
        throw Abort.NotFound
    }
    
    /// Show an instance.
    public func show(request: Request) throws -> ResponseConvertible {
        throw Abort.NotFound
    }
    
    /// Update an instance.
    public func update(request: Request) throws -> ResponseConvertible {
        throw Abort.NotFound
    }
    
    /// Delete an instance.
    public func destroy(request: Request) throws -> ResponseConvertible {
        throw Abort.NotFound
    }
}
