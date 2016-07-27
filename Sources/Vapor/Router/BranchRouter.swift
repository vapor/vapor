import Engine

public typealias Host = String

public final class BranchRouter: Router {

    // MARK: Private Tree Representation
    private final var tree: [Host: [HTTPMethod: Branch]] = [:]

    // MARK: Routing
    public final func route(_ request: Request) -> Responder? {
        let path = request.uri.path 
        let host = request.uri.host

        //get root from hostname, or * route
        let root = tree[host] ?? tree["*"]

        //ensure branch for current method exists
        guard let branch = root?[request.method] else {
            return nil
        }

        //search branch with query path generator
        let generator = path.pathComponentGenerator()
        return branch.handle(request: request, comps: generator)
    }

    // MARK: Registration
    public final func register(_ route: Route) {
        let generator = route.path.pathComponentGenerator()


        //get the current root for the host, or create one if none
        let host = route.hostname
        var base = self.tree[host] ?? [:]

        //look for a branch for the method, or create one if none
        let method = route.method
        let branch = base[method] ?? Branch(name: "")

        //extend the branch
        branch.extendBranch(generator, handler: route.responder)

        //assign the branch and root to the tree
        base[method] = branch
        self.tree[host] = base
    }
}

/**
    Until Swift api is stable for AnyGenerator, using this in interim to allow compiling Swift 2 and 2.2+
*/
public struct CompatibilityGenerator<T>: IteratorProtocol {
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
