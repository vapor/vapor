/**
    Base controller class
*/
public class Controller: ApplicationInitializable, ResourceController {
    /// Access to the current Application instance
    public let app: Application

    public required init(application: Application) {
        self.app = application
    }

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