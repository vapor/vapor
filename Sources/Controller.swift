public class Controller {

	///Create a default controller
	public init() {

	}

	/**
	 * Display many instances.
	 */
	public func index(request: Request) -> ResponseConvertible {
		return "index"
	}

	/**
	 * Create a new instance.
	 */
	public func store(request: Request) -> ResponseConvertible {
		return "store"
	}

	/**
	 * Show an instance.
	 */
	public func show(request: Request) -> ResponseConvertible {
		return "show"
	}

	/**
	 * Update an instance.
	 */
	public func update(request: Request) -> ResponseConvertible {
		return "update"
	}

	/**
	 * Delete an instance.
	 */
	public func destroy(request: Request) -> ResponseConvertible {
		return "destroy"
	}

}