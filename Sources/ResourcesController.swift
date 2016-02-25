/**
 * Organize your routing logic with a conformance of
 * `ResourcesController`. Controls group related route logic into
 * a single protocol that, by default, conforms to standard
 * CRUD operations.
 */
public protocol ResourcesController {
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
