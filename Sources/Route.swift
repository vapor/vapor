extension Application {
    
    public func add(method method: Request.Method, path: String, closure: Route.Handler) {
        let route = Route(method: method, path: path, closure: closure)
        route.hostname = Route.hostname
        
        self.routes.append(route)
    }
    
    public func get(path: String, closure: Route.Handler) {
        self.add(method: .Get, path: path, closure: closure)
    }
    
    public func post(path: String, closure: Route.Handler) {
        self.add(method: .Post, path: path, closure: closure)
    }
    
    public func put(path: String, closure: Route.Handler) {
        self.add(method: .Put, path: path, closure: closure)
    }
    
    public func patch(path: String, closure: Route.Handler) {
        self.add(method: .Patch, path: path, closure: closure)
    }
    
    public func delete(path: String, closure: Route.Handler) {
        self.add(method: .Delete, path: path, closure: closure)
    }
    
    public func options(path: String, closure: Route.Handler) {
        self.add(method: .Options, path: path, closure: closure)
    }
    
    public func any(path: String, closure: Route.Handler) {
        self.get(path, closure: closure)
        self.post(path, closure: closure)
        self.put(path, closure: closure)
        self.patch(path, closure: closure)
        self.delete(path, closure: closure)
    }
    
    public func resource(path: String, controller: Controller) {
        
        let last = "/:id"
        let shortPath = path.componentsSeparatedByString(".")
            .flatMap { component in
                return [component, "/:\(component)_id/"]
            }
            .dropLast()
            .joinWithSeparator("")
        
        // ie: /users
        self.get(shortPath, closure: controller.index)
        self.post(shortPath, closure: controller.store)
        
        // ie: /users/:id
        let fullPath = shortPath + last
        self.get(fullPath, closure: controller.show)
        self.put(fullPath, closure: controller.update)
        self.delete(fullPath, closure: controller.destroy)
    }
    
    public func host(hostname: String, closure: () -> ()) {
        Route.hostname = hostname
        closure()
        Route.hostname = nil
    }

    
}

public class Route {
    static var hostname: String?
    
    public typealias Handler = ((request: Request) throws -> ResponseConvertible)

	let method: Request.Method
	let path: String
	let closure: Route.Handler
    var hostname: String?

	init(method: Request.Method, path: String, closure: Route.Handler) {
		self.method = method
		self.path = path
		self.closure = closure
	}
}

extension Route: CustomStringConvertible {
    public var description: String {
        return "\(self.method) \(self.path) \(self.hostname)"
    }
}