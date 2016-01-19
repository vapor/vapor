public class Route {

	static var routes: [Route] = []

	public enum Method: String {
		case GET = "GET"
		case POST = "POST"
	}

	public typealias Closure = (request: AnyObject) -> AnyObject

	let method: Method
	let path: String
	let closure: Closure

	init(method: Method, path: String, closure: Closure) {
		self.method = method
		self.path = path
		self.closure = closure

		Route.routes.append(self)
	}

	public class func get(path: String, closure: Closure) {
		let _ = Route(method: .GET, path: path, closure: closure)
	}

	public class func resource(path: String, controller: Controller) {
		//TODO: add other methods
		let closure: Closure = { request in
			return controller.index(request)
		}
		let _ = Route(method: .GET, path: path, closure: closure)
	}

}