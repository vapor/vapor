import HTTP

/// A basic router that can route requests depending on the method and URI
///
/// http://localhost:8000/routing/router/
///
/// http://localhost:8000/routing/async/
///
/// http://localhost:8000/routing/sync/
public final class TrieRouter: Router {
    /// All routes registered to this router
    public private(set) var routes: [Route] = []
    
    /// The root node
    var root: RootNode

    public init() {
        self.root = RootNode()
    }

    /// See Router.register()
    public func register(route: Route) {
        self.routes.append(route)
        
        // always start at the root node
        var current: TrieRouterNode = root

        let path = [.constant(route.method.string)] + route.path
        
        // traverse the path components supplied
        var iterator = path.makeIterator()
        while let path = iterator.next() {
            switch path {
            case .constant(let s):
                // find the child node matching this constant
                if let node = current.findConstantNode(at: s) {
                    current = node
                } else {
                    // if no child node matches this constant,
                    // we must create a new one
                    let new = ConstantNode(constant: s)
                    current.constantChildren.append(new)
                    current = new
                }
            case .parameter(let p):
                if let node = current.parameterChild {
                    // there can only ever be one parameter node at
                    // a given node in the tree, so always overwrite the closure
                    current = node
                } else {
                    // if no child node matches this constant,
                    // we must create a new one
                    let new = ParameterNode(parameter: p)
                    current.parameterChild = new
                    current = new
                }
            }
        }

        // set the resolved nodes responder
        current.responder = route.responder
    }
    
    /// Splits the URI into a substring for each component
    fileprivate func split(_ uri: String) -> [Substring] {
        var path = [Substring]()
        path.reserveCapacity(7)
        
        // Skip past the first `/`
        var baseIndex = uri.index(after: uri.startIndex)
        
        if baseIndex < uri.endIndex {
            var currentIndex = baseIndex
            
            // Split up the path
            while currentIndex < uri.endIndex {
                if uri[currentIndex] == "/" {
                    path.append(uri[baseIndex..<currentIndex])
                    
                    baseIndex = uri.index(after: currentIndex)
                    currentIndex = baseIndex
                } else {
                    currentIndex = uri.index(after: currentIndex)
                }
            }
            
            // Add remaining path component
            if baseIndex != uri.endIndex {
                path.append(uri[baseIndex...])
            }
        }
        
        return path
    }
    
    /// Walks the provided node based on the provided component.
    ///
    /// Returns a boolean for a successful walk
    ///
    /// Uses the provided request for parameterized components
    fileprivate func walk<S: StringProtocol>(
        node current: inout TrieRouterNode,
        component: S,
        request: Request
    ) -> Bool {
        if let node = current.findConstantNode(at: String(component)) {
            // if we find a constant route path that matches this component,
            // then we should use it.
            current = node
        } else if let node = current.parameterChild {
            // if no constant routes were found that match the path, but
            // a dynamic parameter child was found, we can use it
            let lazy = LazyParameter(type: node.parameter, value: String(component))
            request.parameters.parameters.append(lazy)
            current = node
        } else {
            // no constant routes were found, and this node doesn't have
            // a dynamic parameter child. so no match.
            return false
        }
        
        return true
    }

    /// See Router.route()
    public func route(request: Request) -> Responder? {
        let path = split(request.uri.path)
        
        // always start at the root node
        var current: TrieRouterNode = root
        
        // Options exception
        if request.method == .options, request.headers[.accessControlRequestMethod] != nil {
            return BasicSyncResponder { _ in
                return Response()
            }
        }
        
        // Start with the method
        guard walk(node: &current, component: request.method.string, request: request) else {
            return nil
        }

        // traverse the constant path supplied
        for component in path {
            guard walk(node: &current, component: component, request: request) else {
                return nil
            }
        }
        
        // return the resolved responder if there hasn't
        // been an early exit.
        return current.responder
    }

}

// MARK: Node Protocol

protocol TrieRouterNode {
    /// All constant child nodes
    var constantChildren: [ConstantNode] { get set }

    /// A node can only ever have one child
    /// of the parameter type. We store this separately
    /// for performance
    var parameterChild: ParameterNode? { get set }

    /// This node's resopnder
    var responder: Responder? { get set }
}

extension TrieRouterNode {
    /// Finds the node with the supplied path in the
    /// node's constant children.
    func findConstantNode(at path: String) -> ConstantNode? {
        for child in constantChildren {
            if child.constant == path {
                return child
            }
        }
        return nil
    }
}

// MARK: Concrete Node

/// An empty node that only has children
/// and doesn't store anything
final class RootNode: TrieRouterNode {
    /// All constant child nodes
    var constantChildren: [ConstantNode]

    /// A node can only ever have one child
    /// of the parameter type. We store this separately
    /// for performance
    var parameterChild: ParameterNode?

    /// This node's resopnder
    var responder: Responder?

    /// Creates a new RouterNode
    init() {
        self.constantChildren = []
    }
}

/// A node that stores a dynamic parameter.
final class ParameterNode: TrieRouterNode {
    /// The parameter type stored at this node
    let parameter: Parameter.Type

    /// All constant child nodes
    var constantChildren: [ConstantNode]

    /// A node can only ever have one child
    /// of the parameter type. We store this separately
    /// for performance
    var parameterChild: ParameterNode?

    /// This node's resopnder
    var responder: Responder?

    /// Creates a new RouterNode
    init(parameter: Parameter.Type) {
        self.parameter = parameter
        self.constantChildren = []
    }
}

/// A node that stores a constant parameter.
final class ConstantNode: TrieRouterNode {
    /// All constant child nodes
    var constantChildren: [ConstantNode]

    /// A node can only ever have one child
    /// of the parameter type. We store this separately
    /// for performance
    var parameterChild: ParameterNode?

    /// This nodes path component
    let constant: String

    /// This node's resopnder
    var responder: Responder?

    /// Creates a new RouterNode
    init(constant: String) {
        self.constant = constant
        self.constantChildren = []
    }
}
