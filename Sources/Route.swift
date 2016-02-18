public class Route {

	static var routes: [Route] = []
    static var hostname: String?

	public typealias Closure = ((request: Request) throws -> ResponseConvertible) 

	let method: Request.Method
	let path: String
	let closure: Closure
    var hostname: String?

	init(method: Request.Method, path: String, closure: Closure) {
		self.method = method
		self.path = path
		self.closure = closure
        
		Route.routes.append(self)
	}
    
    public class func add(method method: Request.Method, path: String, closure: Closure) {
        let route = Route(method: method, path: path, closure: closure)
        route.hostname = self.hostname
    }

	public class func get(path: String, closure: Closure) {
        self.add(method: .Get, path: path, closure: closure)
	}

	public class func post(path: String, closure: Closure) {
		self.add(method: .Post, path: path, closure: closure)
	}

	public class func put(path: String, closure: Closure) {
		self.add(method: .Put, path: path, closure: closure)
	}

	public class func patch(path: String, closure: Closure) {
		self.add(method: .Patch, path: path, closure: closure)
	}

	public class func delete(path: String, closure: Closure) {
		self.add(method: .Delete, path: path, closure: closure)
	}
    
    public class func options(path: String, closure: Closure) {
        self.add(method: .Options, path: path, closure: closure)
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
    
    public class func host(hostname: String, closure: () -> ()) {
        self.hostname = hostname
        closure()
        self.hostname = nil
    }

}

extension Route: CustomStringConvertible {
    public var description: String {
        return "\(self.method) \(self.path) \(self.hostname)"
    }
}