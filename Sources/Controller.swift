public class Controller {

	///Create a default controller
	public init() {

	}

	/**
	 * Display many instances.
	 */
	public func index(request: Request) -> Any {
		return "index"
	}

	/**
	 * Create a new instance.
	 */
	public func store(request: Request) -> Any {
		return "store"
	}

	/**
	 * Show an instance.
	 */
	public func show(request: Request) -> Any {
		return "show"
	}

	/**
	 * Update an instance.
	 */
	public func update(request: Request) -> Any {
		return "update"
	}

	/**
	 * Delete an instance.
	 */
	public func destroy(request: Request) -> Any {
		return "destroy"
	}

}