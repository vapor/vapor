public class Controller {

	///Create a default controller
	public init() {

	}

	/**
	 * Display many instances.
	 */
	public func index(request: Request) -> AnyObject {
		return "index"
	}

	/**
	 * Create a new instance.
	 */
	public func store(request: Request) -> AnyObject {
		return "store"
	}

	/**
	 * Show an instance.
	 */
	public func show(request: Request) -> AnyObject {
		return "show"
	}

	/**
	 * Update an instance.
	 */
	public func update(request: Request) -> AnyObject {
		return "update"
	}

	/**
	 * Delete an instance.
	 */
	public func destroy(request: Request) -> AnyObject {
		return "destroy"
	}

}