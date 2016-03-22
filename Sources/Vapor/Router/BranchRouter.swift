//
//  router.swift
//  HelloServer
//
//  Created by Logan Wright on 2/15/16.
//  Copyright © 2016 LoganWright. All rights reserved.
//

public typealias Host = String


public final class BranchRouter: RouterDriver {

    // MARK: Private Tree Representation

    private final var tree: [Host : [Request.Method : Branch]] = [:]

    // MARK: Routing

    public final func route(request: Request) -> Request.Handler? {
        //get root from hostname, or * route
        let root = tree[request.hostname] ?? tree["*"]

        //ensure branch for current method exists
        guard let branch = root?[request.method] else {
            return nil
        }

        //search branch with query path generator
        let generator = request.path.pathComponentGenerator()
        return branch.handle(request, comps: generator)
    }

    // MARK: Registration

    public final func register(route: Route) {
        let generator = route.path.pathComponentGenerator()


        //get the current root for the host, or create one if none
        let host = route.hostname
        var base = self.tree[host] ?? [:]

        //look for a branch for the method, or create one if none
        let method = route.method
        let branch = base[method] ?? Branch(name: "")

        //extend the branch
        branch.extendBranch(generator, handler: route.handler)

        //assign the branch and root to the tree
        base[method] = branch
        self.tree[host] = base
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

        let components = self.characters.split { character in
            //split on slashes
            return character == "/"
        }.map { item in
            //convert to string array
            return String(item)
        }

        var idx = 0
        return CompatibilityGenerator<String> {
            guard idx < components.count else {
                return nil
            }
            let next = components[idx]
            idx += 1
            return next
        }
    }
}
