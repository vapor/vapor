import HTTP

/// A basic router
public final class TrieRouter: Router {
    /// The root node
    var root: RootNode

    public init() {
        self.root = RootNode()
    }

    /// See Router.register()
    public func register(responder: Responder, at path: [PathComponent]) {
        // always start at the root node
        var current: TrieRouterNode = root

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
                // there can only ever be one parameter node at
                // a given node in the tree, so always create a new one
                let new = ParameterNode(parameter: p)
                current.parameterChild = new
                current = new
            }
        }

        // set the resolved nodes responder
        current.responder = responder
    }

    /// See Router.route()
    public func route(path: [String], parameters: inout ParameterBag) -> Responder? {
        // always start at the root node
        var current: TrieRouterNode = root

        // traverse the constant path supplied
        var iterator = path.makeIterator()
        while let path = iterator.next() {
            if let node = current.findConstantNode(at: path) {
                // if we find a constant route path that matches this component,
                // then we should use it.
                current = node
            } else if let node = current.parameterChild {
                // if no constant routes were found that match the path, but
                // a dynamic parameter child was found, we can use it
                let lazy = LazyParameter(type: node.parameter, value: path)
                parameters.parameters.append(lazy)
                current = node
            } else {
                // no constant routes were found, and this node doesn't have
                // a dynamic parameter child. so no match.
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
