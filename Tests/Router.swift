//
//  router.swift
//  HelloServer
//
//  Created by Logan Wright on 2/15/16.
//  Copyright © 2016 LoganWright. All rights reserved.
//

public typealias Host = String
public typealias RequestHandler = Request throws -> Response
//
//public protocol RouterDriver {
//
//    func route(request: Request) -> (Request -> Response)?
//    func register(hostname hostname: String, method: Request.Method, path: String, handler: (Request -> Response))
//    
//}

//public protocol RouterDriver {
//    
//    func route(request: Request) -> (Request -> Response)?
//    func register(hostname hostname: String?, method: Request.Method, path: String, handler: (Request -> Response))
//    
//}

//extension AltRouter: RouterDriver {
//    public func route(request: Request) -> (Request -> Response)? {
//        // Possibly make overall throwable?
//        // I'm wrapping the throwable version for now
//        guard let handler = handle(request) else { return nil }
//        return {
//            do {
//                try handler($0)
//            }
//        }
//    }
//}

//public protocol RouterDriver {
//    func route(request: Request) -> RequestHandler?
//    func register(hostname hostname: String?, method: Request.Method, path: String, handler: RequestHandler)
//}

extension AltRouter: RouterDriver {
    public func route(request: Request) -> RequestHandler? {
        return handle(request)
    }
    
    public func register(hostname hostname: String = "*", method: Request.Method, path: String, handler: RequestHandler) {
        add(hostname, method: method, path: path, handler: handler)
    }
}

public let Route = AltRouter()

extension AltRouter {
    public final func get(path: String, closure: RequestHandler) {
        add(method: .Get, path: path, handler: closure)
    }
    
    public final func post(path: String, closure: RequestHandler) {
        self.add(method: .Post, path: path, handler: closure)
    }
    
    public final func put(path: String, closure: RequestHandler) {
        self.add(method: .Put, path: path, handler: closure)
    }
    
    public final func patch(path: String, closure: RequestHandler) {
        self.add(method: .Patch, path: path, handler: closure)
    }
    
    public final func delete(path: String, closure: RequestHandler) {
        self.add(method: .Delete, path: path, handler: closure)
    }
    
    public final func options(path: String, closure: RequestHandler) {
        self.add(method: .Options, path: path, handler: closure)
    }
    
    public final func any(path: String, closure: RequestHandler) {
        self.get(path, closure: closure)
        self.post(path, closure: closure)
        self.put(path, closure: closure)
        self.patch(path, closure: closure)
        self.delete(path, closure: closure)
    }
    
    
//    public class func resource(path: String, controller: Controller) {
//        self.get(path, closure: controller.index)
//        self.post(path, closure: controller.store)
//        
//        self.get("\(path)/:id", closure: controller.show)
//        self.put("\(path)/:id", closure: controller.update)
//        self.delete("\(path)/:id", closure: controller.destroy)
//    }
}

public final class AltRouter {
    
    private final var tree: [Host : [Request.Method : Branch]] = [:]
    
    internal init() {}
    
    internal final func handle(request: Request) -> RequestHandler? {
        let root = tree[request.hostname] ?? tree["*"]
        guard
            let branch = root?[request.method]
            else { return nil }
        
        let generator = request
            .path
            .pathComponentGenerator()
        
        return branch.handle(request, comps: generator)
    }
    
    public final func add(host: Host = "*", method: Request.Method, path: String, handler: RequestHandler) {
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
