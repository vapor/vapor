public class AsyncController {

	///Create a default controller
	public init() {

	}

	/**
	 * Display many instances.
	 */
	public func index(request: Request, response: Response) {
		response.send(text: "index")
	}

	/**
	 * Create a new instance.
	 */
	public func store(request: Request, response: Response) {
		response.send(text: "store")
	}

	/**
	 * Show an instance.
	 */
	public func show(request: Request, response: Response) {
		response.send(text: "show")
	}

	/**
	 * Update an instance.
	 */
	public func update(request: Request, response: Response) {
		response.send(text: "update")
	}

	/**
	 * Delete an instance.
	 */
	public func destroy(request: Request, response: Response) {
		response.send(text: "destroy")
	}

}
