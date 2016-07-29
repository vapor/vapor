public typealias Host = String
public typealias Method = String

// MARK: Router

/**
    A simple, flexible, and efficient HTTP Router built on top of Branches
 
    Output represents the object, closure, etc. that the router should be registering and returning
*/
public class Router<Output> {

    // MARK: Private Tree Representation

    /**
        Internal router tree representation.
    */
    private final var tree: [Host: [Method: Branch<Output>]] = [:]

    // MARK: Init

    /**
        Base Initializer
    */
    public init() {}

    // MARK: Registration

    /**
        Register a given path. Use `*` for host OR method to define wildcards that will be matched
        if no concrete match exists.

        - parameter host: the host to match, ie: '0.0.0.0', or `*` to match any
        - parameter method: the method to match, ie: `GET`, or `*` to match any
        - parameter path: the path that should be registered
        - parameter output: the associated output of this path, usually a responder, or `nil`
     */
    public func register(path: [String], output: Output?) {
        let path = path.filter { !$0.isEmpty }
        var iterator = path.makeIterator()

        //get the current root for the host, or create one if none
        let host = iterator.next() ?? "*"
        var base = tree[host] ?? [:]

        //look for a branch for the method, or create one if none
        let method = iterator.next() ?? "*"
        let branch = base[method] ?? Branch(name: "", output: nil)

        //assign the branch and root to the tree
        base[method] = branch
        tree[host] = base

        branch.extend(Array(iterator), output: output)
    }

    // MARK: Route

    /**
        Routes an incoming path, filling the parameters container
        with any found parameters.
     
        If an Output is found, it is returned.
    */
    public func route(path: [String], with container: ParametersContainer) -> Output? {
        let path = path.filter { !$0.isEmpty }

        var iterator = path.makeIterator()
        let host = iterator.next() ?? "*"
        let method = iterator.next() ?? "*"

        let seg = Array(iterator)

        // fetch the result using fallbacks
        let result = tree[host]?[method]?.fetch(seg)
            ?? tree["*"]?[method]?.fetch(seg)
            ?? tree[host]?["*"]?.fetch(seg)
            ?? tree["*"]?["*"]?.fetch(seg)

        container.parameters = result?.branch.slugs(for: seg) ?? [:]
        guard let output = result?.branch.output else {
            return nil
        }
        return output
    }
}
