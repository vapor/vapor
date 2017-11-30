import Async
import HTTP
import Foundation
import Bits

/// A basic router that can route requests depending on the method and URI
///
/// [Learn More →](https://docs.vapor.codes/3.0/routing/router/)
public final class TrieRouter<Output> {
    /// All routes registered to this router
    public private(set) var routes: [Route<Output>] = []
    
    /// The root node
    var root: TrieRouterNode<Output>
    
    /// If a route cannot be found, this is the fallback responder that will be used instead
    public var fallback: Output?

    /// Create a new trie router
    public init() {
        self.root = TrieRouterNode<Output>(kind: .root)
    }

    /// See Router.register()
    public func register(route: Route<Output>) {
        self.routes.append(route)
        
        // always start at the root node
        var current: TrieRouterNode = root
        
        // traverse the path components supplied
        var iterator = route.path.makeIterator()
        while let path = iterator.next() {
            switch path {
            case .constants(let consants):
                for s in consants {
                    // find the child node matching this constant
                    if let node = current.findNode(withConstant: s) {
                        current = node
                    } else {
                        // if no child node matches this constant,
                        // we must create a new one
                        let new = TrieRouterNode<Output>(kind: .constant(s))
                        current.children.append(new)
                        current = new
                    }
                }
            case .parameter(let p):
                if let (node, _) = current.findNode(withParameter: p) {
                    // there can only ever be one parameter node at
                    // a given node in the tree, so always overwrite the closure
                    current = node
                } else {
                    // if no child node matches this constant,
                    // we must create a new one
                    let new = TrieRouterNode<Output>(kind: .parameter(p))
                    current.children.append(new)
                    current = new
                }
            }
        }

        // set the resolved nodes responder
        current.output = route.output
    }
    
    /// Splits the URI into a substring for each component
    fileprivate func split(_ uri: Data) -> [Data] {
        var path = [Data]()
        path.reserveCapacity(8)
        
        // Skip past the first `/`
        var baseIndex = uri.index(after: uri.startIndex)
        
        if baseIndex < uri.endIndex {
            var currentIndex = baseIndex
            
            // Split up the path
            while currentIndex < uri.endIndex {
                if uri[currentIndex] == .forwardSlash {
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
    ///
    /// TODO: Binary data
    fileprivate func walk(
        node current: inout TrieRouterNode<Output>,
        component: Data,
        parameters: ParameterContainer
    ) -> Bool {
        if let node = current.findNode(withConstant: component) {
            // if we find a constant route path that matches this component,
            // then we should use it.
            current = node
        } else if let (node, parameter) = current.firstParameterNode() {
            // if no constant routes were found that match the path, but
            // a dynamic parameter child was found, we can use it
            let lazy = ParameterValue(slug: parameter, value: component)
            parameters.values.append(lazy)
            current = node
        } else {
            // no constant routes were found, and this node doesn't have
            // a dynamic parameter child. so no match.
            return false
        }
        
        return true
    }

    /// See Router.route()
    public func route(path: [Data], parameters: ParameterContainer) -> Output? {
        // always start at the root node
        var current: TrieRouterNode = root

        // traverse the constant path supplied
        for component in path {
            guard walk(node: &current, component: component, parameters: parameters) else {
                return fallback
            }
        }
        
        // return the resolved responder if there hasn't
        // been an early exit.
        return current.output ?? fallback
    }
}
