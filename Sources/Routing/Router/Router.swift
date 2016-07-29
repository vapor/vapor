private typealias Host = String
private typealias Method = String

/**
    When routing objects, it's common for us to want to associate the given slugs or params
    with that object. By conforming here, objects can be passed in.
*/
public protocol ParametersContainer: class {
    /**
        The contained parameters
    */
    var parameters: [String: String] { get set }
}
public final class Branch<Wrapped> {
    public var wrapped: Wrapped?
    public var children: [String: Branch<Wrapped>]

    public init(wrapped: Wrapped? = nil) {
        self.wrapped = wrapped
        children = [:]
    }
}

extension Branch: CustomStringConvertible {
    public var description: String {
        var d: [String] = []
        d.append("\(wrapped)")
        for (key, child) in children {
            d.append("\(key)")
            d.append(child.description.indented)
        }
        return d.joined(separator: "\n")
    }
}

public class Router<Wrapped> {
    public typealias Handler = RouteHandler<Wrapped>
    public typealias RouteBranch = Branch<Handler>

    public var root: RouteBranch

    public func register(path: [String], handler: Handler) {
        print("Register: \(path)")
        let path = path.filter { !$0.isEmpty }
        var branch = root

        for item in path {
            if let found = branch.children[item] {
                branch = found
            } else {
                let new = RouteBranch()
                branch.children[item] = new
                branch = new
            }
        }

        branch.wrapped = handler
    }

    public func route(path: [String], with container: ParametersContainer) -> Wrapped? {
        print("Routing: \(path)")
        let path = path.filter { !$0.isEmpty }
        return route(iterator: path.makeIterator(), with: container, in: root)
    }

    func route(
        iterator: IndexingIterator<[String]>,
        with container: ParametersContainer,
        in branch: RouteBranch
    ) -> Wrapped? {
        var iterator = iterator
        var matches: [RouteBranch] = []

        let locked = Array(iterator)
        guard let item = iterator.next() else {
            if let wrapped = branch.wrapped?.output(path: locked, with: container) {
                return wrapped
            }
            return nil
        }

        if item == "*" {
            matches += branch.children.values
        } else {
            for (key, child) in branch.children {
                if key == "*" || key == item {
                    matches.append(child)
                } else if key.characters.first == ":" {
                    matches.append(child)
                }
            }
        }

        for match in matches {
            if let wrapped = route(
                iterator: iterator,
                with: container,
                in: match
            ) {
                return wrapped
            }
        }

        return nil
    }

    public init() {
        print("Creating a router")
        root = RouteBranch()
    }
}

extension RouteHandler {
    func output(path: [String], with container: ParametersContainer) -> Output? {
        switch self {
        case .dynamic(let closure):
            return closure(path, container)
        case .static(let output):
            return output
        }
    }
}

// MARK: Router

///**
//    A simple, flexible, and efficient HTTP Router built on top of Branches
// 
//    Output represents the object, closure, etc. that the router should be registering and returning
//*/
//public class Router<Output> {
//
//    // MARK: Private Tree Representation
//
//    /**
//        Internal router tree representation.
//    */
//    private final var tree: [Host: [Method: Branch<RouteHandler<Output>>]] = [:]
//
//    // MARK: Init
//
//    /**
//        Base Initializer
//    */
//    public init() {}
//
//    // MARK: Registration
//
//    /**
//     Register a given path. Use `*` for host OR method to define wildcards that will be matched
//     if no concrete match exists.
//
//     - parameter host: the host to match, ie: '0.0.0.0', or `*` to match any
//     - parameter method: the method to match, ie: `GET`, or `*` to match any
//     - parameter path: the path that should be registered
//     - parameter output: the associated output of this path, usually a responder, or `nil`
//     */
//    @discardableResult
//    public func register(path: [String], output: RouteHandler<Output>?) -> Branch<RouteHandler<Output>> {
//        var iterator = path.makeIterator()
//
//        //get the current root for the host, or create one if none
//        let host = iterator.next() ?? "*"
//        var base = tree[host] ?? [:]
//
//        //look for a branch for the method, or create one if none
//        let method = iterator.next() ?? "*"
//        let branch = base[method] ?? Branch(name: "", handler: nil)
//
//        //assign the branch and root to the tree
//        base[method] = branch
//        tree[host] = base
//
//        let path = Array(iterator)
//        return branch.extend(path, output: output)
//    }
//
//    // MARK: Route
//
//    public func route(_ routeable: Routeable, with container: ParametersContainer) -> Output? {
//        var iterator = routeable.routeablePath.makeIterator()
//
//        let host = iterator.next() ?? "*"
//        let root = tree[host] ?? tree["*"]
//
//        let method = iterator.next() ?? "*"
//
//        let path = Array(iterator)
//
//        // MUST fetch here, do NOT do `root?[method] ?? root?["*"]`
//        let result = root?[method]?
//            .fetch(path)?
//            .branch
//            .output?
//            .output(with: routeable, container: container)
//            ?? root?["*"]?
//                .fetch(path)?
//                .branch
//                .output?
//                .output(with: routeable, container: container)
//
//        guard let output = result else {
//            return nil
//        }
//
//        return output
//    }
//}


extension String {
    private var components: [String] {
        return characters
            .split(separator: "/", omittingEmptySubsequences: true)
            .map { String($0) }
    }
}
