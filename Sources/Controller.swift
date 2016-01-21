public class Controller {

	///Create a default controller
	public init() {

	}

	/**
	 * Display many instances.
	 */
	public func index(request: Request) -> AnyObject {
		return "index" as! AnyObject
	}

	/**
	 * Create a new instance.
	 */
	public func store(request: Request) -> AnyObject {
		return "store" as! AnyObject
	}

	/**
	 * Show an instance.
	 */
	public func show(request: Request) -> AnyObject {
		return "show" as! AnyObject
	}

	/**
	 * Update an instance.
	 */
	public func update(request: Request) -> AnyObject {
		return "update" as! AnyObject
	}

	/**
	 * Delete an instance.
	 */
	public func destroy(request: Request) -> AnyObject {
		return "destroy" as! AnyObject
	}

}