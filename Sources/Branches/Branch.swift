import Engine
import Base

extension Branch {
    public func params(for path: [String]) -> [String: String] {
        var params: [String: String] = [:]
        parameterIndexes.forEach { key, index in
            guard let val = path[safe: index].flatMap({ percentDecoded($0.bytes) }) else { return }
            params[key] = val.string
        }
        return params
    }
}

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

     */
    public private(set) var parent: Branch?

    public private(set) lazy var path: [String] = {
        guard let parent = self.parent else { return [] }
        return parent.path + [self.name]
    }()

    public private(set) lazy var depth: Int = {
        guard let parent = self.parent else { return 0 }
        return 1 + parent.depth
    }()

    public private(set) lazy var parameterIndexes: [(key: String, idx: Int)] = {
        var params = self.parent?.parameterIndexes ?? []
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

    public var output: Output? {
        return value ?? fallback
    }

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

    public func fetch(_ path: IndexingIterator<[String]>) -> BranchResult<Output>? {
        var comps = path
        guard let key = comps.next() else { return BranchResult(self, comps) }

        if let result = subBranches[key]?.fetch(comps) where result.branch.hasValidOutput {
            return result
        }

        if let result = subBranches[":"]?.fetch(comps) where result.branch.hasValidOutput {
            return result
        }
        if let wildcard = subBranches["*"] where wildcard.hasValidOutput {
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
        _ = next.parameterIndexes
        subBranches[link] = next
        return next.extend(path, output: output)
    }
}
