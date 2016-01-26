public class Route {

	static var routes: [Route] = []

	public typealias Closure = (request: Request) -> Any

	let method: Request.Method
	let path: String
	let closure: Closure

	init(method: Request.Method, path: String, closure: Closure) {
		self.method = method
		self.path = path
		self.closure = closure

		Route.routes.append(self)
	}

	public class func get(path: String, closure: Closure) {
		let _ = Route(method: .Get, path: path, closure: closure)
	}

	public class func post(path: String, closure: Closure) {
		let _ = Route(method: .Post, path: path, closure: closure)
	}

	public class func put(path: String, closure: Closure) {
		let _ = Route(method: .Put, path: path, closure: closure)
	}

	public class func patch(path: String, closure: Closure) {
		let _ = Route(method: .Patch, path: path, closure: closure)
	}

	public class func delete(path: String, closure: Closure) {
		let _ = Route(method: .Delete, path: path, closure: closure)
	}

	public class func any(path: String, closure: Closure) {
		self.get(path, closure: closure)
		self.post(path, closure: closure)
		self.put(path, closure: closure)
		self.patch(path, closure: closure)
		self.delete(path, closure: closure)
	}


	public class func resource(path: String, controller: Controller) {
		self.get(path, closure: controller.index)
		self.post(path, closure: controller.store)

		self.get("\(path)/:id", closure: controller.show)
		self.put("\(path)/:id", closure: controller.update)
		self.delete("\(path)/:id", closure: controller.destroy)
	}

}