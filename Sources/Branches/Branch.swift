import Core

extension Branch {
    /**
        It is not uncommon to place slugs along our branches representing keys that will
        match for the path given. When this happens, the path can be laid across here to extract
        slug values efficiently.
     
        Branches: `path/to/:name`
        Given Path: `path/to/joe`
        
            let slugs = branch.slugs(for: givenPath) // ["name": "joe"]
    */
    public func slugs(for path: [String]) -> [String: String] {
        var slugs: [String: String] = [:]
        slugIndexes.forEach { key, index in
            guard let val = path[safe: index].flatMap({ percentDecoded($0.bytes) }) else { return }
            slugs[key] = val.string
        }
        return slugs
    }
}

/**
    Branch result is used to encapsulate some metadata when fetching a branch.
 
    Less useful now, but will likely play role in chaining in future using remaining iterator.
*/
public class BranchResult<Output> {
    public let branch: Branch<Output>
    public let remaining: IndexingIterator<[String]>

    init(_ branch: Branch<Output>, _ remaining: IndexingIterator<[String]>) {
        self.branch = branch
        self.remaining = remaining
    }
}

/**
     When routing requests, different branches will be established,
     in a linked list style stemming from their host and request method.
     It can be represented as:

     | host | request.method | branch -> branch -> branch
*/
public class Branch<Output> { // TODO: Rename Context

    /**
         The name of the branch, ie if we have a path hello/:name,
         the branch structure will be:
         Branch('hello') (connected to) Branch('name')

         In cases where a slug is used, ie ':name' the slug
         will be used as the name and passed as a key in matching.
    */
    public let name: String

    /**
        The immediate parent of this branch. `nil` if current branch is a terminator
    */
    public private(set) var parent: Branch?

    /*
        The leading path that corresponds to this given branch.
    */
    public private(set) lazy var path: [String] = {
        guard let parent = self.parent else { return [] }
        return parent.path + [self.name]
    }()

    /**
        The current depth of a given tree branch. If tip of branch, returns `0`
    */
    public private(set) lazy var depth: Int = {
        guard let parent = self.parent else { return 0 }
        return 1 + parent.depth
    }()

    /**
        A branch with a name beginning with `:` will be considered a `slug` or `parameter` branch.
        This means that the branch can match any name, but represents a key value pair with associated path.
        This value is used to extract parameters from a path list in an efficient way.
    */
    public private(set) lazy var slugIndexes: [(key: String, idx: Int)] = {
        var params = self.parent?.slugIndexes ?? []
        guard self.name.hasPrefix(":") else { return params }
        let characters = self.name.characters.dropFirst()
        let key = String(characters)
        params.append((key, self.depth - 1))
        return params
    }()

    /**
         There are two types of branches, those that support a handler,
         and those that are a linker between branches,
         for example /users/messages/:id will have 3 connected branches,
         only one of which supports a handler.

         Branch('users') -> Branch('messages') -> *Branches('id')

         *indicates a supported branch.
    */
    private var value: Output?

    /**
        Associated output the branch corresponds to
    */
    public var output: Output? {
        return value ?? fallback
    }

    /**
        Some branches are links in a chain, some are a destination that has output.
    */
    private var hasValidOutput: Bool {
        guard let _ = value ?? fallback else { return false }
        return true
    }

    /**
         key or : or *

         If it is a `key`, then it connects to an additional branch.

         If it is `:`, it is a slug point and the name
         represents a key for a dynamic value.
    */
    private var subBranches: [String : Branch<Output>] = [:]


    /**
         Fallback routes allow various handlers to "catch" any subsequent paths on its branch that
         weren't otherwise matched
    */
    private var fallback: Output? {
        return subBranches["*"]?.value
    }

    /**
         Used to create a new branch

         - parameter name: The name associated with the branch, or the key when dealing with a slug
         - parameter handler: The handler to be called if its a valid endpoint, or `nil` if this is a bridging branch

         - returns: an initialized request Branch
    */
    required public init(name: String, output: Output? = nil) {
        self.name = name
        self.value = output
    }

    /**
         This function will recursively traverse the branch
         until the path is fulfilled or the branch ends

         - parameter request: the request to use in matching
         - parameter comps:   ordered pathway components generator

         - returns: a request handler or nil if not supported
    */
    public func fetch(_ path: [String]) -> BranchResult<Output>? {
        return fetch(path.makeIterator())
    }



    /**
         This function will recursively traverse the branch
         until the path is fulfilled or the branch ends

         - parameter request: the request to use in matching
         - parameter comps:   ordered pathway components generator

         - returns: a request handler or nil if not supported
    */
    public func fetch(_ path: IndexingIterator<[String]>) -> BranchResult<Output>? {
        var comps = path
        guard let key = comps.next() else { return BranchResult(self, comps) }

        if let result = subBranches[key]?.fetch(comps), result.branch.hasValidOutput {
            return result
        }

        if let result = subBranches[":"]?.fetch(comps), result.branch.hasValidOutput {
            return result
        }

        if let result = subBranches["*"]?.fetch(comps), result.branch.hasValidOutput {
            return result
        }

        if let wildcard = subBranches["*"], wildcard.hasValidOutput {
            let subRoute = [key] + comps
            return BranchResult(wildcard, subRoute.makeIterator())
        }

        return nil
    }

    @discardableResult
    public func extend(_ path: [String], output: Output?) -> Branch {
        return extend(path.makeIterator(), output: output)
    }

    /**
         If a branch exists that is linked as:

         Branch('one') -> Branch('two')

         This branch will be extended with the given value

         - parameter generator: the generator that will be used to match the path components.  /users/messages/:id will return a generator that is 'users' <- 'messages' <- '*id'
         - parameter handler:   the handler to assign to the end path component
    */
    @discardableResult
    public func extend(_ path: IndexingIterator<[String]>, output: Output?) -> Branch {
        var path = path
        guard let key = path.next() else {
            self.value = output
            return self
        }

        let link = key.characters.first == ":" ? ":" : key
        let next = subBranches[link] ?? self.dynamicType.init(name: key, output: nil)
        next.parent = self
        // trigger lazy loads at extension time -- seek out cleaner way to do this
        _ = next.path
        _ = next.depth
        _ = next.slugIndexes
        subBranches[link] = next
        return next.extend(path, output: output)
    }
}
