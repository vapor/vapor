import Core
import HTTP
import Routing

/// Converts a router into a responder.
public struct RouterResponder: Responder {
    let router: Router
    public init(router: Router) {
        self.router = router
    }

    public func respond(to req: Request) throws -> Future<Response> {
        guard let responder = router.route(request: req) else {
            return Future(Response(status: .notFound))
        }

        return try responder.respond(to: req)
    }
}

extension TrieRouter: AsyncRouter, SyncRouter { }

extension AsyncRouter {
    @discardableResult
    public func get<F: FutureType>(
        _ path: PathComponentRepresentable...,
        use closure: @escaping BasicAsyncResponder<F>.Closure
    ) -> Route where F.Expectation: ResponseRepresentable {
        return self.on(.get, to: path.makePathComponents(), use: closure)
    }
    
    @discardableResult
    public func put<F: FutureType>(
        _ path: PathComponentRepresentable...,
        use closure: @escaping BasicAsyncResponder<F>.Closure
    ) -> Route where F.Expectation: ResponseRepresentable {
        return self.on(.put, to: path.makePathComponents(), use: closure)
    }
    
    @discardableResult
    public func post<F: FutureType>(
        _ path: PathComponentRepresentable...,
        use closure: @escaping BasicAsyncResponder<F>.Closure
    ) -> Route where F.Expectation: ResponseRepresentable {
        return self.on(.post, to: path.makePathComponents(), use: closure)
    }
    
    @discardableResult
    public func delete<F: FutureType>(
        _ path: PathComponentRepresentable...,
        use closure: @escaping BasicAsyncResponder<F>.Closure
    ) -> Route where F.Expectation: ResponseRepresentable {
        return self.on(.delete, to: path.makePathComponents(), use: closure)
    }
    
    @discardableResult
    public func patch<F: FutureType>(
        _ path: PathComponentRepresentable...,
        use closure: @escaping BasicAsyncResponder<F>.Closure
    ) -> Route where F.Expectation: ResponseRepresentable {
        return self.on(.patch, to: path.makePathComponents(), use: closure)
    }
}

extension SyncRouter {
    @discardableResult
    public func get(
        _ path: PathComponentRepresentable...,
        use closure: @escaping BasicSyncResponder.Closure
    ) -> Route {
        return self.on(.get, to: path.makePathComponents(), use: closure)
    }
    
    @discardableResult
    public func put(
        _ path: PathComponentRepresentable...,
        use closure: @escaping BasicSyncResponder.Closure
    ) -> Route {
        return self.on(.put, to: path.makePathComponents(), use: closure)
    }
    
    @discardableResult
    public func post(
        _ path: PathComponentRepresentable...,
        use closure: @escaping BasicSyncResponder.Closure
    ) -> Route {
        return self.on(.post, to: path.makePathComponents(), use: closure)
    }
    
    @discardableResult
    public func delete(
        _ path: PathComponentRepresentable...,
        use closure: @escaping BasicSyncResponder.Closure
    ) -> Route {
        return self.on(.delete, to: path.makePathComponents(), use: closure)
    }
    
    @discardableResult
    public func patch(
        _ path: PathComponentRepresentable...,
        use closure: @escaping BasicSyncResponder.Closure
    ) -> Route {
        return self.on(.patch, to: path.makePathComponents(), use: closure)
    }
}
