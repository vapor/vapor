//
//  Branch.swift
//  HelloServer
//
//  Created by Logan Wright on 2/15/16.
//  Copyright © 2016 LoganWright. All rights reserved.
//

/**
 When routing requests, different branches will be established, in a linked list style stemming from their host and request method.  It can be represented as
 
    | host | request.method | branch -> branch -> branch
 */
internal final class Branch {
    
    /**
     The name of the branch, ie if we have a path hello/:name, the branch structure will be
        Branch('hello') (connected to) Branch('name')
     
     In cases where a slug is used, ie ':name' the slug will be used as the name and passed as a key in matching
     */
    let name: String
    
    /**
     There are two types of branches, those that support a handler, and those that are a linker between branches, for example /users/messages/:id will have 3 connected branches, only one of which supports a handler
     
        Branch('users') -> Branch('messages') -> *Branches('id')
        *indicates a supported branch
     */
    private var handler: Request.Handler?
    
    /**
     key or *
     
     if it is a `key`, then it connects to an additional branch
     if it is `*`, it is a slug point and the name represents a key for a dynamic value
     
     */
    private(set) var subBranches: [String : Branch] = [:]
    
    /**
     Used to create a new branch
     
     - parameter name:    the name associated with the branch, or the key when dealing with a slug
     - parameter handler: the handler to be called if its a valid endpoint, or `nil` if this is a bridging branch
     
     - returns: an initialized request Branch
     */
    init(name: String, handler: Request.Handler? = nil) {
        self.name = name
        self.handler = handler
    }
   
    /**
     This function will recursively traverse the branch until the path is fulfilled or the branch ends
     
     - parameter request: the request to use in matching
     - parameter comps:   ordered pathway components generator
     
     - returns: a request handler or nil if not supported
     */
    @warn_unused_result
    func handle(request: Request, comps: AnyGenerator<String>) -> Request.Handler? {
        guard let key = comps.next() else {
            return handler
        }
        
        if let next = subBranches[key] {
            return next.handle(request, comps: comps)
        } else if let wildcard = subBranches["*"] {
            request.parameters[wildcard.name] = key.stringByRemovingPercentEncoding
            return wildcard.handle(request, comps: comps)
        } else {
            return nil
        }
    }

    /**
     If a branch exists that is linked as:
     
         Branch('one') -> Branch('two')
     
     This branch will be extended with the given value
     
     - parameter generator: the generator that will be used to match the path components.  /users/messages/:id will return a generator that is 'users' <- 'messages' <- '*id'
     - parameter handler:   the handler to assign to the end path component
     */
    func extendBranch(generator: AnyGenerator<String>, handler: Request.Handler) {
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
