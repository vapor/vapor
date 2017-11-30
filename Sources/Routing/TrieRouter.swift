import Async
import HTTP
import Foundation
import Bits

/// A basic router that can route requests depending on the method and URI
///
/// [Learn More →](https://docs.vapor.codes/3.0/routing/router/)
public final class TrieRouter: Router {
    /// All routes registered to this router
    public private(set) var routes: [Route] = []
    
    /// The root node
    var root: RootNode
    
    /// If a route cannot be found, this is the fallback responder that will be used instead
    public var fallbackResponder: Responder? = BasicResponder { _ in
        return Future(Response(status: .notFound))
    }

    public init() {
        self.root = RootNode()
    }

    /// See Router.register()
    public func register(route: Route) {
        self.routes.append(route)
        
        // always start at the root node
        var current: TrieRouterNode = root

        let path = [.constants([route.method.string])] + route.path
        
        // traverse the path components supplied
        var iterator = path.makeIterator()
        while let path = iterator.next() {
            switch path {
            case .constants(let consants):
                for s in consants {
                    let count = s.utf8.count
                    
                    // find the child node matching this constant
                    s.withCString { pointer in
                        pointer.withMemoryRebound(to: UInt8.self, capacity: count) { pointer in
                            if let node = current.findConstantNode(at: ByteBuffer(start: pointer, count: count)) {
                                current = node
                            } else {
                                // if no child node matches this constant,
                                // we must create a new one
                                let new = ConstantNode(constant: s)
                                current.constantChildren.append(new)
                                current = new
                            }
                        }
                    }
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
    fileprivate func forEachComponent(in uri: ByteBuffer, do closure: (ByteBuffer) -> (Bool)) -> Bool {
        // Skip past the first `/`
        var baseIndex = uri.index(after: uri.startIndex)
        
        if baseIndex < uri.endIndex {
            var currentIndex = baseIndex
            
            // Split up the path
            while currentIndex < uri.endIndex {
                if uri[currentIndex] == .forwardSlash {
                    guard closure(ByteBuffer(start: uri.baseAddress?.advanced(by: baseIndex), count: currentIndex - baseIndex)) else {
                        return false
                    }
                    
                    baseIndex = uri.index(after: currentIndex)
                    currentIndex = baseIndex
                } else {
                    currentIndex = uri.index(after: currentIndex)
                }
            }
            
            // Add remaining path component
            if baseIndex != uri.endIndex {
                return closure(ByteBuffer(start: uri.baseAddress?.advanced(by: baseIndex), count: uri.endIndex - baseIndex))
            }
        }
        
        return false
    }
    
    /// Walks the provided node based on the provided component.
    ///
    /// Returns a boolean for a successful walk
    ///
    /// Uses the provided request for parameterized components
    ///
    /// TODO: Binary data
    fileprivate func walk(
        node current: inout TrieRouterNode,
        component: ByteBuffer,
        request: Request
    ) -> Bool {
        if let node = current.findConstantNode(at: component) {
            // if we find a constant route path that matches this component,
            // then we should use it.
            current = node
        } else if let node = current.parameterChild {
            // if no constant routes were found that match the path, but
            // a dynamic parameter child was found, we can use it
            let lazy = LazyParameter(slug: node.parameter, value: String(bytes: component, encoding: .utf8) ?? "")
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
        return request.uri.pathBytes.withUnsafeBufferPointer { (buffer: ByteBuffer) in
            // always start at the root node
            var current: TrieRouterNode = root
            
            var found = request.method.bytes.withUnsafeBufferPointer {  (buffer: ByteBuffer) in
                walk(node: &current, component: buffer, request: request)
            }
            
            guard found else {
                return fallbackResponder
            }
            
            found = forEachComponent(in: buffer) { component in
                return walk(node: &current, component: component, request: request)
            }
            
            // return the resolved responder if there hasn't
            // been an early exit.
            return current.responder ?? fallbackResponder
        }
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
    func findConstantNode(at path: ByteBuffer) -> ConstantNode? {
        guard let pointer = path.baseAddress else {
            return nil
        }
        
        for child in constantChildren {
            guard path.count == child.constant.count else {
                continue
            }
            
            if memcmp(pointer, child.constant, path.count) == 0 {
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
    let parameter: String

    /// All constant child nodes
    var constantChildren: [ConstantNode]

    /// A node can only ever have one child
    /// of the parameter type. We store this separately
    /// for performance
    var parameterChild: ParameterNode?

    /// This node's resopnder
    var responder: Responder?

    /// Creates a new RouterNode
    init(parameter: String) {
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
    let constant: [UInt8]

    /// This node's resopnder
    var responder: Responder?

    /// Creates a new RouterNode
    ///
    /// TODO: Binary data
    init(constant: String) {
        self.constant = [UInt8](constant.utf8)
        self.constantChildren = []
    }
}
