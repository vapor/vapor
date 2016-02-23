/**
 * Organize your routing logic with a conformance of
 * `Controller`. Controls group related route logic into
 * a single protocol that, by default, conforms to standard
 * CRUD operations.
 */
public protocol Controller: class {
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

extension Controller {
	public func index(request: Request) throws -> ResponseConvertible {
		return "index"
	}

	public func store(request: Request) throws -> ResponseConvertible {
		return "store"
	}

	public func show(request: Request) throws -> ResponseConvertible {
		return "show"
	}

	public func update(request: Request) throws -> ResponseConvertible {
		return "update"
	}

	public func destroy(request: Request) throws -> ResponseConvertible {
		return "destroy"
	}    
}
