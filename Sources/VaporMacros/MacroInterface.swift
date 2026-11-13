#if MacroRouting
public import HTTPTypes
public import Vapor

// Group macros are markers; this member role lifts their handlers before Swift
// resolves any controller properties referenced by the group's configuration.
@attached(member, names: arbitrary)
@attached(extension, conformances: RouteCollection, names: named(boot(routes:)))
public macro Controller() =
    #externalMacro(
        module: "VaporMacrosPlugin",
        type: "ControllerMacro",
    )

@attached(peer, names: prefixed(_route_), prefixed(_register_))
public macro GET(on routeBuilder: (any RoutesBuilder)? = nil, _ pathComponents: Any...) =
    #externalMacro(
        module: "VaporMacrosPlugin",
        type: "HTTPGetMacro"
    )

@attached(peer, names: prefixed(_route_), prefixed(_register_))
public macro POST(on routeBuilder: (any RoutesBuilder)? = nil, _ pathComponents: Any...) =
    #externalMacro(
        module: "VaporMacrosPlugin",
        type: "HTTPPostMacro"
    )

/// Decodes the request body as `Body` and passes it to the first
/// non-authentication handler parameter after `Request`.
/// If `Body` is also the authentication type, the first parameter of that
/// type receives the body and a later parameter receives the authenticated user.
/// For example: `@POST(content: User.self, "users")`.
@attached(peer, names: prefixed(_route_), prefixed(_register_))
public macro POST<Body: ContentDecodable>(content: Body.Type, on routeBuilder: (any RoutesBuilder)? = nil, _ pathComponents: Any...) =
    #externalMacro(
        module: "VaporMacrosPlugin",
        type: "HTTPPostMacro"
    )

@attached(peer, names: prefixed(_route_), prefixed(_register_))
public macro PUT(on routeBuilder: (any RoutesBuilder)? = nil, _ pathComponents: Any...) =
    #externalMacro(
        module: "VaporMacrosPlugin",
        type: "HTTPPutMacro"
    )

@attached(peer, names: prefixed(_route_), prefixed(_register_))
public macro DELETE(on routeBuilder: (any RoutesBuilder)? = nil, _ pathComponents: Any...) =
    #externalMacro(
        module: "VaporMacrosPlugin",
        type: "HTTPDeleteMacro"
    )

@attached(peer, names: prefixed(_route_), prefixed(_register_))
public macro PATCH(on routeBuilder: (any RoutesBuilder)? = nil, _ pathComponents: Any...) =
    #externalMacro(
        module: "VaporMacrosPlugin",
        type: "HTTPPatchMacro"
    )

@attached(peer, names: prefixed(_route_), prefixed(_register_))
public macro HTTP(on routeBuilder: (any RoutesBuilder)? = nil, _ method: HTTPRequest.Method, _ pathComponents: Any...) =
    #externalMacro(
        module: "VaporMacrosPlugin",
        type: "HTTPMethodMacro"
    )

// MARK: - Freestanding Route Macros
// Use these inside function bodies for standalone route registration.
// The @attached(peer) versions above don't work for local functions due to
// a Swift compiler limitation where peer declarations are silently dropped.

@freestanding(declaration, names: arbitrary)
public macro GET(on routeBuilder: any RoutesBuilder, _ pathComponents: Any..., handler: Any) =
    #externalMacro(
        module: "VaporMacrosPlugin",
        type: "FreestandingGetMacro"
    )

@freestanding(declaration, names: arbitrary)
public macro POST(on routeBuilder: any RoutesBuilder, _ pathComponents: Any..., handler: Any) =
    #externalMacro(
        module: "VaporMacrosPlugin",
        type: "FreestandingPostMacro"
    )

@freestanding(declaration, names: arbitrary)
public macro PUT(on routeBuilder: any RoutesBuilder, _ pathComponents: Any..., handler: Any) =
    #externalMacro(
        module: "VaporMacrosPlugin",
        type: "FreestandingPutMacro"
    )

@freestanding(declaration, names: arbitrary)
public macro DELETE(on routeBuilder: any RoutesBuilder, _ pathComponents: Any..., handler: Any) =
    #externalMacro(
        module: "VaporMacrosPlugin",
        type: "FreestandingDeleteMacro"
    )

@freestanding(declaration, names: arbitrary)
public macro PATCH(on routeBuilder: any RoutesBuilder, _ pathComponents: Any..., handler: Any) =
    #externalMacro(
        module: "VaporMacrosPlugin",
        type: "FreestandingPatchMacro"
    )

@freestanding(declaration, names: arbitrary)
public macro HTTP(on routeBuilder: any RoutesBuilder, _ method: HTTPRequest.Method, _ pathComponents: Any..., handler: Any) =
    #externalMacro(
        module: "VaporMacrosPlugin",
        type: "FreestandingHTTPMethodMacro"
    )

@attached(peer)
public macro AuthMiddleware<T: Authenticatable>(_ authenticationType: T.Type, _ middleware: any Middleware...) =
    #externalMacro(
        module: "VaporMacrosPlugin",
        type: "AuthMiddlewareMacro"
    )

/// Groups route handlers with authentication middleware inside a `@Controller`.
@freestanding(declaration)
public macro AuthMiddleware<T: Authenticatable>(
    _ authenticationType: T.Type,
    _ middleware: any Middleware...,
    body: () -> Void
) = #externalMacro(module: "VaporMacrosPlugin", type: "AuthMiddlewareMacro")

/// Groups route handlers with middleware inside a `@Controller`.
/// Use the `using:` overload when the middleware needs controller dependencies.
@freestanding(declaration)
public macro Middleware(
    _ middleware: any Middleware...,
    body: () -> Void
) = #externalMacro(module: "VaporMacrosPlugin", type: "FreestandingMiddlewareMacro")

/// Injects an authenticated handler parameter using middleware resolved from its controller.
///
/// Pass a key-path literal such as `\Self.authentication`, or a factory such as
/// `{ (controller: Self) in UserAuthenticator(databases: controller.databases) }`.
/// The generated `boot(routes:)` evaluates the factory with the controller instance.
@attached(peer)
public macro AuthMiddleware<T: Authenticatable, Controller>(
    _ authenticationType: T.Type,
    using middleware: (Controller) -> any Middleware
) = #externalMacro(module: "VaporMacrosPlugin", type: "AuthMiddlewareMacro")

/// Groups authenticated routes using a controller's middleware property or factory.
///
/// For example, `#AuthMiddleware(User.self, using: \Self.authentication) { ... }`.
/// A factory runs during route registration, once for each route in the group.
@freestanding(declaration)
public macro AuthMiddleware<T: Authenticatable, Controller>(
    _ authenticationType: T.Type,
    using middleware: (Controller) -> any Middleware,
    body: () -> Void
) = #externalMacro(module: "VaporMacrosPlugin", type: "AuthMiddlewareMacro")

/// Groups routes using a controller's middleware property or factory.
///
/// For example, `#Middleware(using: \Self.loggingMiddleware) { ... }`, or
/// `#Middleware(using: { (controller: Self) in APIMiddleware(client: controller.client) }) { ... }`.
/// The key path or factory is type-checked at the declaration site and evaluated
/// with `self` in the generated `boot(routes:)`, once per route. Store the middleware
/// on the controller if the routes should share the same middleware instance.
@freestanding(declaration)
public macro Middleware<Controller>(
    using middleware: (Controller) -> any Middleware,
    body: () -> Void
) = #externalMacro(module: "VaporMacrosPlugin", type: "FreestandingMiddlewareMacro")
#endif
