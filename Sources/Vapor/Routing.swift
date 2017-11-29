import Async
import Bits
import Foundation
import HTTP
import Routing

/// Groups collections of routes together for adding
/// to a router.
public protocol RouteCollection {
    /// Registers routes to the incoming router.
    func boot(router: Router) throws
}

public protocol Router {
    func register(route: Route<Responder>)
    func route(request: Request) -> Responder?
}

public struct EngineRouter {
    private let router: TrieRouter<Responder>

    public init() {
        self.router = .init()
    }

    public func register(route: Route<Responder>) {
        router.register(route: route)
    }

    public func route(request: Request) -> Responder? {
        return router.route(
            path: [request.http.method.data] + request.http.uri.pathData.split(separator: .forwardSlash),
            parameters: request
        )
    }
}



extension Router {
    /// Registers all of the routes in the group
    /// to this router.
    public func register(collection: RouteCollection) throws {
        try collection.boot(router: self)
    }
}

public protocol Responder {
    func respond(to req: Request) throws -> Future<Response>
}

/// A stream containing an  responder.
public final class ResponderStream: Async.Stream {
    /// See InputStream.Input
    public typealias Input = HTTPRequest

    /// See OutputStream.Output
    public typealias Output = HTTPResponse

    /// The base responder
    private let responder: Responder

    /// Worker to pass onto incoming requests
    public let worker: Worker

    /// Container to pass onto incoming requests
    public let container: Container

    /// Use a basic stream to easily implement our output stream.
    private var outputStream: BasicStream<Output>

    /// Create a new response stream.
    /// The responses will be awaited on the supplied queue.
    public init(responder: Responder, on worker: Worker, using container: Container) {
        self.responder = responder
        self.outputStream = .init()
        self.worker = worker
        self.container = container
    }

    /// See InputStream.onInput
    public func onInput(_ input: Input) {
        let req = Request(http: input, on: worker, using: container)
        do {
            // dispatches the incoming request to the responder.
            // the response is awaited on the responder stream's queue.
            try responder.respond(to: req)
                .map { ($0 as Response).http as HTTPResponse }
                .stream(to: outputStream)
        } catch {
            self.onError(error)
        }
    }

    /// See InputStream.onError
    public func onError(_ error: Error) {
        outputStream.onError(error)
    }

    /// See OutputStream.onOutput
    public func onOutput<I>(_ input: I) where I: Async.InputStream, Output == I.Input {
        outputStream.onOutput(input)
    }

    /// See CloseableStream.close
    public func close() {
        outputStream.close()
    }

    /// See CloseableStream.onClose
    public func onClose(_ onClose: ClosableStream) {
        outputStream.onClose(onClose)
    }
}


/// A basic, closure-based responder.
public struct BasicResponder: Responder {
    /// Responder closure
    public typealias Closure = (Request) throws -> Future<Response>

    /// The stored responder closure.
    public let closure: Closure

    /// Create a new basic responder.
    public init(closure: @escaping Closure) {
        self.closure = closure
    }

    /// See: .Responder.respond
    public func respond(to req: Request) throws -> Future<Response> {
        return try closure(req)
    }
}

/// Can be converted from a response.
///
/// [Learn More →](https://docs.vapor.codes/3.0/http/response/#responseinitializable)
public protocol ResponseDecodable {
    static func decode(from res: Response, for req: Request) throws -> Future<Self>
}

/// Can be converted to a response
///
/// [Learn More →](https://docs.vapor.codes/3.0/http/response/#responserepresentable)
public protocol ResponseEncodable {
    /// Makes a response using the context provided by the HTTPRequest
    func encode(to res: inout Response, for req: Request) throws -> Future<Void>
}

/// Can be converted from and to a response
public typealias ResponseCodable = ResponseDecodable & ResponseEncodable

// MARK: Response Conformance

extension Response: ResponseEncodable {
    /// See ResponseRepresentable.makeResponse
    public func encode(to res: inout Response, for req: Request) throws -> Future<Void> {
        res = self
        return .done
    }
}

extension HTTPResponse: ResponseEncodable, FutureType {
    public typealias Expectation = HTTPResponse

    /// See ResponseRepresentable.makeResponse
    public func encode(to res: inout Response, for req: Request) throws -> Future<Void> {
        let new = req.makeResponse()
        new.http = self
        res = new
        return .done
    }
}

/// Makes `Response` a drop-in replacement for `Future<Response>
extension Response: FutureType {
    public typealias Expectation = Response
}



/// Can be converted from a request.
public protocol RequestDecodable {
    static func decode(from req: Request) throws -> Future<Self>
}

/// Can be converted to a request
public protocol RequestEncodable {
    func encode(to req: inout Request) throws -> Future<Void>
}

/// Can be converted from and to a request
public typealias RequestCodable = RequestDecodable & RequestEncodable

// MARK: Request Conformance

extension Request: RequestEncodable {
    public func encode(to req: inout Request) throws -> Future<Void> {
        req = self
        return .done
    }
}

extension Request: RequestDecodable {
    /// See RequestInitializable.decode
    public static func decode(from request: Request) throws -> Future<Request> {
        return Future(request)
    }
}





/// Capable of being used as a route parameter.
///
/// [Learn More →](https://docs.vapor.codes/3.0/routing/parameters/#creating-custom-parameters)
public protocol Parameter {
    /// the type of this parameter after it has been resolved.
    associatedtype ResolvedParameter

    /// the unique key to use as a slug in route building
    static var uniqueSlug: String { get }

    // returns the found model for the resolved url parameter
    static func make(for parameter: String, in request: Request) throws -> ResolvedParameter
}

extension Parameter {
    /// The path component for this route parameter
    public static var parameter: PathComponent {
        return .parameter(Data(uniqueSlug.utf8))
    }
}

extension Parameter {
    /// See Parameter.uniqueSlug
    public static var uniqueSlug: String {
        return "\(Self.self)"
    }
}

extension Parameter where Self: EphemeralWorkerFindable {
    /// See Parameter.make
    public static func make(for parameter: String, in request: Request) throws -> EphemeralWorkerFindableResult {
        return try find(identifier: parameter, for: request)
    }
}

extension Request {
    /// Grabs the next parameter from the parameter bag.
    ///
    /// Note: the parameters _must_ be fetched in the order they
    /// appear in the path.
    ///
    /// For example GET /posts/:post_id/comments/:comment_id
    /// must be fetched in this order:
    ///
    ///     let post = try parameters.next(Post.self)
    ///     let comment = try parameters.next(Comment.self)
    ///
    public func next<P>(_ parameter: P.Type = P.self) throws -> P.ResolvedParameter
        where P: Parameter
    {
        guard parameters.count > 0 else {
            throw VaporError(identifier: "insufficientParameters", reason: "Insufficient parameters")
        }

        let current = parameters[0]
        guard current.slug == Data(P.uniqueSlug.utf8) else {
            throw VaporError(identifier: "invalidParameterType", reason: "Invalid parameter type. Expected \(P.self) got \(current.slug)")
        }

        let item = try P.make(for: String(data: current.value, encoding: .utf8) ?? "", in: self)
        parameters = Array(parameters.dropFirst())
        return item
    }

    /// Infer requested type where the resolved parameter is the parameter type.
    public func next<P>() throws -> P
        where P: Parameter, P.ResolvedParameter == P
    {
        return try self.next(P.self)
    }
}

/// Capable of registering async routes.
extension Router {
    /// Registers a route handler at the supplied path.
    @discardableResult
    public func on<F: FutureType>(
        _ method: HTTPMethod,
        to path: [PathComponent],
        use closure: @escaping RouteResponder<F>.Closure
    ) -> Route<Responder> where F.Expectation: ResponseEncodable {
        let responder = RouteResponder(closure: closure)
        let route = Route<Responder>(
            path: [.constants([method.data])] + path,
            output: responder
        )
        self.register(route: route)
        return route
    }
}

/// A basic, closure-based responder.
public struct RouteResponder<F: FutureType>: Responder
    where F.Expectation: ResponseEncodable
{
    /// Responder closure
    public typealias Closure = (Request) throws -> F

    /// The stored responder closure.
    public let closure: Closure

    /// Create a new basic responder.
    public init(closure: @escaping Closure) {
        self.closure = closure
    }

    /// See: HTTP.Responder.respond
    public func respond(to req: Request) throws -> Future<Response> {
        return try closure(req).then { rep -> Future<Response> in
            var res = req.makeResponse()
            return try rep.encode(to: &res, for: req).map {
                return res
            }
        }
    }
}


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
            let res = req.makeResponse()
            res.http.status = .notFound
            return Future(res)
        }

        return try responder.respond(to: req)
    }
}

extension Router {
    /// Creates a `Route` at the provided path using the `GET` method.
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/getting-started/routing/)
    @discardableResult
    public func get<F: FutureType>(
        _ path: PathComponent...,
        use closure: @escaping RouteResponder<F>.Closure
    ) -> Route<Responder> where F.Expectation: ResponseEncodable {
        return self.on(.get, to: path, use: closure)
    }
    
    /// Creates a `Route` at the provided path using the `PUT` method.
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/getting-started/routing/)
    @discardableResult
    public func put<F: FutureType>(
        _ path: PathComponent...,
        use closure: @escaping RouteResponder<F>.Closure
    ) -> Route<Responder> where F.Expectation: ResponseEncodable {
        return self.on(.put, to: path, use: closure)
    }
    
    /// Creates a `Route` at the provided path using the `POST` method.
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/getting-started/routing/)
    @discardableResult
    public func post<F: FutureType>(
        _ path: PathComponent...,
        use closure: @escaping RouteResponder<F>.Closure
    ) -> Route<Responder> where F.Expectation: ResponseEncodable {
        return self.on(.post, to: path, use: closure)
    }
    
    /// Creates a `Route` at the provided path using the `DELETE` method.
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/getting-started/routing/)
    @discardableResult
    public func delete<F: FutureType>(
        _ path: PathComponent...,
        use closure: @escaping RouteResponder<F>.Closure
    ) -> Route<Responder> where F.Expectation: ResponseEncodable {
        return self.on(.delete, to: path, use: closure)
    }
    
    /// Creates a `Route` at the provided path using the `PATCH` method.
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/getting-started/routing/)
    @discardableResult
    public func patch<F: FutureType>(
        _ path: PathComponent...,
        use closure: @escaping RouteResponder<F>.Closure
    ) -> Route<Responder> where F.Expectation: ResponseEncodable {
        return self.on(.patch, to: path, use: closure)
    }
}
