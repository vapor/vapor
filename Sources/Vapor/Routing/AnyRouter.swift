/// Type-erased `Router`
public struct AnyRouter<Output>: Router {
    private let box: _AnyRouterBase<Output>
    
    public init<Router>(_ base: Router) where Router: RoutingKit.Router, Router.Output == Output {
        self.box = _AnyRouterBox(base)
    }
    
    public func register(_ output: Output, at path: [PathComponent]) {
        box.register(output, at: path)
    }
    
    public func route(path: [String], parameters: inout Parameters) -> Output? {
        box.route(path: path, parameters: &parameters)
    }
}

extension Router {
    /// Create a type-erased `Router` from the receiving type
    public func eraseToAnyRouter() -> AnyRouter<Output> {
        return AnyRouter(self)
    }
}

private class _AnyRouterBase<Output>: Router {
    init() {
        guard type(of: self) != _AnyRouterBase.self else {
            fatalError("_AnyRouterBase<Output> instances can not be created. Subclass instead.")
        }
    }
    
    func register(_ output: Output, at path: [PathComponent]) {
        fatalError("Must be overridden")
    }
    
    func route(path: [String], parameters: inout Parameters) -> Output? {
        fatalError("Must be overridden")
    }
}

private final class _AnyRouterBox<Concrete>: _AnyRouterBase<Concrete.Output> where Concrete: Router {
    var concrete: Concrete
    
    init(_ concrete: Concrete) {
        self.concrete = concrete
    }
    
    override func register(_ output: Output, at path: [PathComponent]) {
        concrete.register(output, at: path)
    }
    
    override func route(path: [String], parameters: inout Parameters) -> Concrete.Output? {
        concrete.route(path: path, parameters: &parameters)
    }
}
