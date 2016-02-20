//
//  router.swift
//  HelloServer
//
//  Created by Logan Wright on 2/15/16.
//  Copyright © 2016 LoganWright. All rights reserved.
//

public let altRouter = AltRouter()

public typealias RequestHandler = Request throws -> Response

public final class AltRouter {
    
    private final var tree: [Request.Method : Branch] = [:]
    
    internal init() {}
    
    internal final func resolve(request: Request) throws -> Response? {
        guard
            let branch = tree[request.method]
            else { return nil }

        let generator = request
            .path
            .pathComponentGenerator()
        return try branch.handle(request, comps: generator)
    }
    
    public final func add(method: Request.Method, path: String, handler: RequestHandler) {
        let generator = path.pathComponentGenerator()
        let branch = tree[method] ?? Branch(name: "")
        branch.extendBranch(generator, handler: handler)
        tree[method] = branch
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
