/**
 * Organize your routing logic with a conformance of
 * `Controller`. Controls group related route logic into
 * a single protocol that, by default, conforms to standard
 * CRUD operations.
 */
public class Controller {
    public init() {}

    /// Display many instances
	public func index(request: Request) throws -> ResponseConvertible {
        return ""
    }

    /// Create a new instance.
    public func store(request: Request) throws -> ResponseConvertible {
        return ""
    }

    /// Show an instance.
    public func show(request: Request) throws -> ResponseConvertible {
        return ""
    }

    /// Update an instance.
    public func update(request: Request) throws -> ResponseConvertible {
        return ""
    }

    /// Delete an instance.
    public func destroy(request: Request) throws -> ResponseConvertible {
        return ""
    }
}