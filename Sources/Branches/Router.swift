public typealias Host = String

public protocol ParameterContainer: class {
    var parameters: [String: String] { get set }
}

// MARK: Router

public class Router<Output> {

    // MARK: Private Tree Representation

    private final var tree: [Host: [String: Branch<Output>]] = [:]

    // MARK: Init

    public init() {}

    // MARK: Registration

    @discardableResult
    public func register(host: String = "*", method: String, path: String, output: Output?) -> Branch<Output> {
        let generator = path.components

        //get the current root for the host, or create one if none
        var base = tree[host] ?? [:]

        //look for a branch for the method, or create one if none
        let branch = base[method] ?? Branch<Output>(name: "", output: nil)

        //assign the branch and root to the tree
        base[method] = branch
        tree[host] = base

        return branch.extend(generator, output: output)
    }

    // MARK: Route

    public func route(for paramContainer: ParameterContainer? = nil, host: String = "*", method: String, path: String) -> Output? {
        let path = path.components

        // get root from hostname, or * route
        let root = tree[host] ?? tree["*"]

        // MUST fetch here, do NOT do `root?[method] ?? root?["*"]`
        let result = root?[method]?.fetch(path) ?? root?["*"]?.fetch(path)
        paramContainer?.parameters = result?.branch.params(for: path) ?? [:]
        return result?.branch.output
    }
}

extension String {
    private var components: [String] {
        return characters
            .split(separator: "/", omittingEmptySubsequences: true)
            .map { String($0) }
    }
}
