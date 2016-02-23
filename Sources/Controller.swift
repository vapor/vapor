/**
 * Organize your routing logic with a conformance of
 * `Controller`. Controls group related route logic into
 * a single protocol that, by default, conforms to standard
 * CRUD operations.
 */
public class Controller {
    /// Display many instances
	func index(request: Request) throws -> ResponseConvertible {
        return ""
    }

    /// Create a new instance.
    func store(request: Request) throws -> ResponseConvertible {
        return ""
    }

    /// Show an instance.
    func show(request: Request) throws -> ResponseConvertible {
        return ""
    }

    /// Update an instance.
    func update(request: Request) throws -> ResponseConvertible {
        return ""
    }

    /// Delete an instance.
    func destroy(request: Request) throws -> ResponseConvertible {
        return ""
    }
}