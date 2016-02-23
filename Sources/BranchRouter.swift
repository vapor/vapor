//
//  router.swift
//  HelloServer
//
//  Created by Logan Wright on 2/15/16.
//  Copyright © 2016 LoganWright. All rights reserved.
//

public typealias Host = String

extension Application {
    
    public typealias Handler = Request throws -> ResponseConvertible
    
    public final func get(path: String, closure: Handler) {
        self.add(.Get, path: path, closure: closure)
    }
    
    public final func post(path: String, closure: Handler) {
        self.add(.Post, path: path, closure: closure)
    }
    
    public final func put(path: String, closure: Handler) {
        self.add(.Put, path: path, closure: closure)
    }
    
    public final func patch(path: String, closure: Handler) {
        self.add(.Patch, path: path, closure: closure)
    }
    
    public final func delete(path: String, closure: Handler) {
        self.add(.Delete, path: path, closure: closure)
    }
    
    public final func options(path: String, closure: Handler) {
        self.add(.Options, path: path, closure: closure)
    }
    
    public final func any(path: String, closure: Handler) {
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
    
    public final func add(method: Request.Method, path: String, closure: Handler) {
        router.register(hostname: host, method: method, path: path) { request in
            return try closure(request).response()
        }
    }
    
    public final func host(host: String, closure: () -> Void) {
        let original = self.host
        self.host = host
        closure()
        self.host = original
    }
}

public final class BranchRouter: RouterDriver {
    
    // MARK: Private Tree Representation
    
    private final var tree: [Host : [Request.Method : Branch]] = [:]
    
    // MARK: Routing
    
    public final func route(request: Request) -> Request.Handler? {
        let root = tree[request.hostname] ?? tree["*"]
        guard
            let branch = root?[request.method]
            else { return nil }
        
        let generator = request
            .path
            .pathComponentGenerator()
        
        return branch.handle(request, comps: generator)
    }
    
    // MARK: Registration
    
    public final func register(hostname hostname: String = "*", method: Request.Method, path: String, handler: Request.Handler) {
        let generator = path.pathComponentGenerator()
        var root = tree[hostname] ?? [:]
        let branch = root[method] ?? Branch(name: "")
        branch.extendBranch(generator, handler: handler)
        root[method] = branch
        tree[hostname] = root
    }
}

/**
 *  Until Swift api is stable for AnyGenerator, using this in interim to allow compiling Swift 2 and 2.2+
 */
public struct CompatibilityGenerator<T>: GeneratorType {
    public typealias Element = T
    
    private let closure: () -> T?
    
    init(closure: () -> T?) {
        self.closure = closure
    }
    
    public func next() -> Element? {
        return closure()
    }
}

extension String {
    private func pathComponentGenerator() -> CompatibilityGenerator<String> {
        let comps = self
            .characters
            .split { $0 == "/" }
            .map(String.init)
        
        var idx = 0
        return CompatibilityGenerator<String> {
            guard idx < comps.count else {
                return nil
            }
            let next = comps[idx]
            idx += 1
            return next
        }
    }
}
