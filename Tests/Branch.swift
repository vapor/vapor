//
//  Branch.swift
//  HelloServer
//
//  Created by Logan Wright on 2/15/16.
//  Copyright © 2016 LoganWright. All rights reserved.
//

internal final class Branch {
    
    let name: String
    private var handler: RequestHandler?
    
    // key or *, possibly use different data structure since only 2 options.  Not either / or, both can exist simultaneously.  Named component takes precedence
    private(set) var subBranches: [String : Branch] = [:]
    
    init(name: String, handler: RequestHandler? = nil) {
        self.name = name
        self.handler = handler
    }
    
    @warn_unused_result
    func handle(request: Request, comps: AnyGenerator<String>) throws -> Response? {
        guard let key = comps.next() else {
            return try handler?(request)
        }
        
        if let next = subBranches[key] {
            return try next.handle(request, comps: comps)
        } else if let wildcard = subBranches["*"] {
            request.parameters[wildcard.name] = key
            return try wildcard.handle(request, comps: comps)
        } else {
            return nil
        }
    }
    
    func extendBranch(generator: AnyGenerator<String>, handler: RequestHandler) {
        guard let key = generator.next() else {
            self.handler = handler
            return
        }
        
        if key.hasPrefix(":") {
            let chars = key.characters
            let indexOne = chars.startIndex.advancedBy(1)
            let sub = key.characters.suffixFrom(indexOne)
            let substring = String(sub)
            let next = subBranches["*"] ?? Branch(name: substring)
            next.extendBranch(generator, handler: handler)
            subBranches["*"] = next
        } else {
            let next = subBranches[key] ?? Branch(name: key)
            next.extendBranch(generator, handler: handler)
            subBranches[key] = next
        }
    }
}
