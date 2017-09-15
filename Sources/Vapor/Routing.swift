import Core
import HTTP
import Routing

/// Converts a router into a responder.
public struct RouterResponder: Responder {
    let router: Router
    
    /// Creates a new responder for a router
    public init(router: Router) {
        self.router = router
    }

    /// Responds to a request using the Router
    public func respond(to req: Request) throws -> Future<Response> {
        guard let responder = router.route(request: req) else {
            return Future(Response(status: .notFound))
        }

        return try responder.respond(to: req)
    }
}

/// Makes `TrieRouter` both an `AsyncRouter` and `SyncRouter`
extension TrieRouter: AsyncRouter, SyncRouter { }

extension AsyncRouter {
    /// Creates an Async `Route` at the provided path using the `GET` method.
    @discardableResult
    public func get<F: FutureType>(
        _ path: PathComponentRepresentable...,
        use closure: @escaping BasicAsyncResponder<F>.Closure
    ) -> Route where F.Expectation: ResponseRepresentable {
        return self.on(.get, to: path.makePathComponents(), use: closure)
    }
    
    /// Creates  Async `Route` at the provided path using the `PUT` method.
    @discardableResult
    public func put<F: FutureType>(
        _ path: PathComponentRepresentable...,
        use closure: @escaping BasicAsyncResponder<F>.Closure
    ) -> Route where F.Expectation: ResponseRepresentable {
        return self.on(.put, to: path.makePathComponents(), use: closure)
    }
    
    /// Creates  Async `Route` at the provided path using the `POST` method.
    @discardableResult
    public func post<F: FutureType>(
        _ path: PathComponentRepresentable...,
        use closure: @escaping BasicAsyncResponder<F>.Closure
    ) -> Route where F.Expectation: ResponseRepresentable {
        return self.on(.post, to: path.makePathComponents(), use: closure)
    }
    
    /// Creates  Async `Route` at the provided path using the `DELETE` method.
    @discardableResult
    public func delete<F: FutureType>(
        _ path: PathComponentRepresentable...,
        use closure: @escaping BasicAsyncResponder<F>.Closure
    ) -> Route where F.Expectation: ResponseRepresentable {
        return self.on(.delete, to: path.makePathComponents(), use: closure)
    }
    
    /// Creates  Async `Route` at the provided path using the `PATCH` method.
    @discardableResult
    public func patch<F: FutureType>(
        _ path: PathComponentRepresentable...,
        use closure: @escaping BasicAsyncResponder<F>.Closure
    ) -> Route where F.Expectation: ResponseRepresentable {
        return self.on(.patch, to: path.makePathComponents(), use: closure)
    }
}

extension SyncRouter {
    /// Creates  Sync `Route` at the provided path using the `GET` method.
    @discardableResult
    public func get(
        _ path: PathComponentRepresentable...,
        use closure: @escaping BasicSyncResponder.Closure
    ) -> Route {
        return self.on(.get, to: path.makePathComponents(), use: closure)
    }
    
    /// Creates  Sync `Route` at the provided path using the `PUT` method.
    @discardableResult
    public func put(
        _ path: PathComponentRepresentable...,
        use closure: @escaping BasicSyncResponder.Closure
    ) -> Route {
        return self.on(.put, to: path.makePathComponents(), use: closure)
    }
    
    /// Creates  Sync `Route` at the provided path using the `POST` method.
    @discardableResult
    public func post(
        _ path: PathComponentRepresentable...,
        use closure: @escaping BasicSyncResponder.Closure
    ) -> Route {
        return self.on(.post, to: path.makePathComponents(), use: closure)
    }
    
    /// Creates  Sync `Route` at the provided path using the `DELETE` method.
    @discardableResult
    public func delete(
        _ path: PathComponentRepresentable...,
        use closure: @escaping BasicSyncResponder.Closure
    ) -> Route {
        return self.on(.delete, to: path.makePathComponents(), use: closure)
    }
    
    /// Creates  Sync `Route` at the provided path using the `PATCH` method.
    @discardableResult
    public func patch(
        _ path: PathComponentRepresentable...,
        use closure: @escaping BasicSyncResponder.Closure
    ) -> Route {
        return self.on(.patch, to: path.makePathComponents(), use: closure)
    }
}
