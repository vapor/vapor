#if MacroRouting
import HTTPTypes
import Vapor

@attached(extension, conformances: RouteCollection, names: named(boot(routes:)))
public macro Controller(_ pathComponents: Any...) = #externalMacro(
    module: "VaporMacrosPlugin",
    type: "ControllerMacro",
)

@attached(peer, names: arbitrary)
public macro GET(on routeBuilder: (any RoutesBuilder)? = nil, _ pathComponents: Any...) = #externalMacro(
    module: "VaporMacrosPlugin",
    type: "HTTPGetMacro"
)

@attached(peer, names: arbitrary)
public macro POST(on routeBuilder: (any RoutesBuilder)? = nil, _ pathComponents: Any...) = #externalMacro(
    module: "VaporMacrosPlugin",
    type: "HTTPPostMacro"
)

@attached(peer, names: arbitrary)
public macro PUT(on routeBuilder: (any RoutesBuilder)? = nil, _ pathComponents: Any...) = #externalMacro(
    module: "VaporMacrosPlugin",
    type: "HTTPPutMacro"
)

@attached(peer, names: arbitrary)
public macro DELETE(on routeBuilder: (any RoutesBuilder)? = nil, _ pathComponents: Any...) = #externalMacro(
    module: "VaporMacrosPlugin",
    type: "HTTPDeleteMacro"
)

@attached(peer, names: arbitrary)
public macro PATCH(on routeBuilder: (any RoutesBuilder)? = nil, _ pathComponents: Any...) = #externalMacro(
    module: "VaporMacrosPlugin",
    type: "HTTPPatchMacro"
)

@attached(peer, names: arbitrary)
public macro HTTP(on routeBuilder: (any RoutesBuilder)? = nil, _ method: HTTPRequest.Method, _ pathComponents: Any...) = #externalMacro(
    module: "VaporMacrosPlugin",
    type: "HTTPMethodMacro"
)

// MARK: - Freestanding Route Macros
// Use these inside function bodies for standalone route registration.
// The @attached(peer) versions above don't work for local functions due to
// a Swift compiler limitation where peer declarations are silently dropped.

@freestanding(declaration, names: arbitrary)
public macro GET(on routeBuilder: any RoutesBuilder, _ pathComponents: Any..., handler: Any) = #externalMacro(
    module: "VaporMacrosPlugin",
    type: "FreestandingGetMacro"
)

@freestanding(declaration, names: arbitrary)
public macro POST(on routeBuilder: any RoutesBuilder, _ pathComponents: Any..., handler: Any) = #externalMacro(
    module: "VaporMacrosPlugin",
    type: "FreestandingPostMacro"
)

@freestanding(declaration, names: arbitrary)
public macro PUT(on routeBuilder: any RoutesBuilder, _ pathComponents: Any..., handler: Any) = #externalMacro(
    module: "VaporMacrosPlugin",
    type: "FreestandingPutMacro"
)

@freestanding(declaration, names: arbitrary)
public macro DELETE(on routeBuilder: any RoutesBuilder, _ pathComponents: Any..., handler: Any) = #externalMacro(
    module: "VaporMacrosPlugin",
    type: "FreestandingDeleteMacro"
)

@freestanding(declaration, names: arbitrary)
public macro PATCH(on routeBuilder: any RoutesBuilder, _ pathComponents: Any..., handler: Any) = #externalMacro(
    module: "VaporMacrosPlugin",
    type: "FreestandingPatchMacro"
)

@freestanding(declaration, names: arbitrary)
public macro HTTP(on routeBuilder: any RoutesBuilder, _ method: HTTPRequest.Method, _ pathComponents: Any..., handler: Any) = #externalMacro(
    module: "VaporMacrosPlugin",
    type: "FreestandingHTTPMethodMacro"
)

@attached(peer)
public macro AuthMiddleware<T: Authenticatable>(_ authenticationType: T.Type, _ middleware: any Middleware...) = #externalMacro(
    module: "VaporMacrosPlugin",
    type: "AuthMiddlewareMacro"
)
#endif
