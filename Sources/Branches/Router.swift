private typealias Host = String
private typealias Method = String

/**
    When routing objects, it's common for us to want to associate the given slugs or params
    with that object. By conforming here, objects can be passed in.
*/
public protocol ParameterContainer: class {
    /**
        The contained parameters
    */
    var parameters: [String: String] { get set }
}

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
    @discardableResult
    public func register(host: String = "*", method: String, path: [String], output: Output?) -> Branch<Output> {
        //get the current root for the host, or create one if none
        var base = tree[host] ?? [:]

        //look for a branch for the method, or create one if none
        let branch = base[method] ?? Branch<Output>(name: "", output: nil)

        //assign the branch and root to the tree
        base[method] = branch
        tree[host] = base

        return branch.extend(path, output: output)
    }

    /**
         Register a given path. Use `*` for host OR method to define wildcards that will be matched
         if no concrete match exists.

         - parameter host: the host to match, ie: '0.0.0.0', or `*` to match any
         - parameter method: the method to match, ie: `GET`, or `*` to match any
         - parameter path: the path that should be registered separated by `/`
         - parameter output: the associated output of this path, usually a responder, or `nil`
     */
    @discardableResult
    public func register(host: String = "*", method: String, path: String, output: Output?) -> Branch<Output> {
        return register(host: host, method: method, path: path.components, output: output)
    }

    // MARK: Route

    /**
         Fetches and returns the output, if exists, for a given route.

         - parameter for paramContainer: an object that will have its slug parameters automatically set
         - parameter host: the host to match to
         - parameter method: the method associated with the route
         - parameter path: the path to use in routing
     */
    public func route(for paramContainer: ParameterContainer? = nil, host: String, method: String, path: [String]) -> Output? {
        // get root from hostname, or * route
        let root = tree[host] ?? tree["*"]

        // MUST fetch here, do NOT do `root?[method] ?? root?["*"]`
        let result = root?[method]?.fetch(path) ?? root?["*"]?.fetch(path)
        paramContainer?.parameters = result?.branch.slugs(for: path) ?? [:]
        return result?.branch.output
    }

    /**
     Fetches and returns the output, if exists, for a given route.

     - parameter for paramContainer: an object that will have its slug parameters automatically set
     - parameter host: the host to match to
     - parameter method: the method associated with the route
     - parameter path: the path to use in routing
     */
    public func route(for paramContainer: ParameterContainer? = nil, host: String, method: String, path: String) -> Output? {
        return route(for: paramContainer, host: host, method: method, path: path.components)
    }
}

extension String {
    private var components: [String] {
        return characters
            .split(separator: "/", omittingEmptySubsequences: true)
            .map { String($0) }
    }
}
