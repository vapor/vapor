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
    public func register(host: Host?, method: Method?, path: [String], output: Output?) {
        //get the current root for the host, or create one if none
        let host = host ?? "*"
        var base = tree[host] ?? [:]

        //look for a branch for the method, or create one if none
        let method = method ?? "*"
        let branch = base[method] ?? Branch(name: "", handler: nil)

        //assign the branch and root to the tree
        base[method] = branch
        tree[host] = base

        let path = path.filter { !$0.isEmpty }
        branch.extend(path, output: output)
    }

    // MARK: Route

    public func route(host: Host?, method: Method?, path: [String], with container: ParametersContainer) -> Output? {
        let host = host ?? "*"
        let method = method ?? "*"
        let path = path.filter { !$0.isEmpty }

        // fetch the result using fallbacks
        let result = tree["*"]?[method]?.fetch(path)
            ?? tree["*"]?["*"]?.fetch(path)
            ?? tree[host]?[method]?.fetch(path)
            ?? tree[host]?["*"]?.fetch(path)

        container.parameters = result?.branch.slugs(for: path) ?? [:]
        guard let output = result?.branch.output else {
            return nil
        }
        return output
    }
}

extension Router: CustomStringConvertible {
    public var description: String {
        var d: [String] = []
        for (host, mb) in tree {
            d.append(host)
            for (method, branch) in mb {
                d.append(method.indented)
                d.append(branch.description.indented.indented)
            }
        }
        return d.joined(separator: "\n")
    }
}

