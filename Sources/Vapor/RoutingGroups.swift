import HTTP
import Routing

public final class Group : Router {
    let `super`: Router
    let components: [PathComponent]
    
    init(cascadingTo router: Router, components: [PathComponent] = []) {
        self.super = router
        self.components = components
    }
    
    public func register(route: Route) {
        route.path.insert(contentsOf: self.components, at: 0)
        self.super.register(route: route)
    }
    
    public func route(request: Request) -> Responder? {
        return self.super.route(request: request)
    }
}

extension Router {
    public func group(_ path: PathComponentRepresentable..., use: ((Group) -> ())) {
        use(Group(cascadingTo: self, components: path.makePathComponents()))
    }
    
    public func grouped(_ path: PathComponentRepresentable...) -> Group {
        return Group(cascadingTo: self)
    }
}
