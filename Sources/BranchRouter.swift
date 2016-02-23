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
    
    public final func register(hostname hostname: String?, method: Request.Method, path: String, handler: Request.Handler) {
        let generator = path.pathComponentGenerator()
        
        let host = hostname ?? "*"
        
        //get the current root for the host, or create one if none
        var root = self.tree[host] ?? [:]
        
        //look for a branch for the method, or create one if none
        let branch = root[method] ?? Branch(name: "")
        
        //extend the branch
        branch.extendBranch(generator, handler: handler)
        
        //assign the branch and root to the tree
        root[method] = branch
        self.tree[host] = root
    }
}

extension String {
    private func pathComponentGenerator() -> AnyGenerator<String> {
        
        let components = self.characters.split { character in
            //split on slashes
            return character == "/"
        }.map { item in
            //convert to string array
            return String(item)
        }
        
        var counter = 0
        return AnyGenerator<String> {
            guard counter < components.count else {
                return nil
            }
            
            let next = components[counter]
            counter += 1
            
            return next
        }
    }
}
