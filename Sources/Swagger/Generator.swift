import Routing

extension Router {
    public func describeAPI(named name: String) throws -> OpenAPI {
        let api = OpenAPI(named: name)
        
        for route in routes {
            let item: PathItem
                
            if let route = route.swaggerRoute {
                item = route
            } else {
                item = PathItem()
            }
            
            api.paths[route.path] = item
        }
        
        return api
    }
}

extension Route {
    public var swaggerRoute: PathItem? {
        get {
            return extend["swagger:PathItem"] as? PathItem
        }
        set {
            extend["swagger:PathItem"] = newValue
        }
    }
    
    public func describe(as description: String, using closure: ((PathItem) throws -> (Operation))) rethrows {
        let path = self.swaggerRoute ?? PathItem()
        
        path.description = description
        path.parameters = self.path.makeParameters()
        
        let operation = try closure(path)
        
        switch self.method {
        case .get: path.get = operation
        case .put: path.put = operation
        case .post: path.post = operation
        case .delete: path.delete = operation
        case .patch: path.patch = operation
        case .options: path.options = operation
        default: break
        }
    }
}

fileprivate extension Array where Element == PathComponent {
    func makeParameters() -> [PossibleReference<Parameter>] {
        return self.flatMap { component in
            guard case .parameter(let parameter) = component else {
                return nil
            }
            
            return .direct(Parameter(named: parameter.uniqueSlug, in: .path))
        }
    }
}
