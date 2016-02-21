//
//  router.swift
//  HelloServer
//
//  Created by Logan Wright on 2/15/16.
//  Copyright © 2016 LoganWright. All rights reserved.
//

public typealias Host = String

public let Route = Router()

extension Request {
    public typealias Handler = Request throws -> ResponseConvertible
}

extension Router: RouterDriver {
    public func route(request: Request) -> Request.Handler? {
        return handle(request)
    }
    
    public func register(hostname hostname: String = "*", method: Request.Method, path: String, handler: Request.Handler) {
        add(hostname, method: method, path: path, handler: handler)
    }
}

extension Router {
    public final func get(path: String, closure: Request.Handler) {
        add(method: .Get, path: path, handler: closure)
    }
    
    public final func post(path: String, closure: Request.Handler) {
        self.add(method: .Post, path: path, handler: closure)
    }
    
    public final func put(path: String, closure: Request.Handler) {
        self.add(method: .Put, path: path, handler: closure)
    }
    
    public final func patch(path: String, closure: Request.Handler) {
        self.add(method: .Patch, path: path, handler: closure)
    }
    
    public final func delete(path: String, closure: Request.Handler) {
        self.add(method: .Delete, path: path, handler: closure)
    }
    
    public final func options(path: String, closure: Request.Handler) {
        self.add(method: .Options, path: path, handler: closure)
    }
    
    public final func any(path: String, closure: Request.Handler) {
        self.get(path, closure: closure)
        self.post(path, closure: closure)
        self.put(path, closure: closure)
        self.patch(path, closure: closure)
        self.delete(path, closure: closure)
    }

    public final func resource(path: String, controller: Controller) {
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
}

public final class Router {
    
    private final var tree: [Host : [Request.Method : Branch]] = [:]
    
    internal init() {}
    
    internal final func handle(request: Request) -> Request.Handler? {
        let root = tree[request.hostname] ?? tree["*"]
        guard
            let branch = root?[request.method]
            else { return nil }
        
        let generator = request
            .path
            .pathComponentGenerator()
        
        return branch.handle(request, comps: generator)
    }
    
    public final func add(host: Host = "*", method: Request.Method, path: String, handler: Request.Handler) {
        let generator = path.pathComponentGenerator()
        var root = tree[host] ?? [:]
        let branch = root[method] ?? Branch(name: "")
        branch.extendBranch(generator, handler: handler)
        root[method] = branch
        tree[host] = root
    }
}

extension String {
    private func pathComponentGenerator() -> AnyGenerator<String> {
        let comps = self
            .characters
            .split { $0 == "/" }
            .map(String.init)
        
        var idx = 0
        return AnyGenerator<String> {
            guard idx < comps.count else {
                return nil
            }
            let next = comps[idx]
            idx += 1
            return next
        }
    }
}
