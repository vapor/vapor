import HTTPTypes
import Vapor

@attached(extension, conformances: RouteCollection, names: named(boot(routes:)))
public macro Controller() = #externalMacro(
    module: "VaporMacrosPlugin",
    type: "ControllerMacro",
)

@attached(peer, names: prefixed(_route_))
public macro GET(_ pathComponents: Any...) = #externalMacro(
    module: "VaporMacrosPlugin",
    type: "HTTPGetMacro"
)

@attached(peer, names: prefixed(_route_))
public macro POST(_ pathComponents: Any...) = #externalMacro(
    module: "VaporMacrosPlugin",
    type: "HTTPPostMacro"
)

@attached(peer, names: prefixed(_route_))
public macro PUT(_ pathComponents: Any...) = #externalMacro(
    module: "VaporMacrosPlugin",
    type: "HTTPPutMacro"
)

@attached(peer, names: prefixed(_route_))
public macro DELETE(_ pathComponents: Any...) = #externalMacro(
    module: "VaporMacrosPlugin",
    type: "HTTPDeleteMacro"
)

@attached(peer, names: prefixed(_route_))
public macro PATCH(_ pathComponents: Any...) = #externalMacro(
    module: "VaporMacrosPlugin",
    type: "HTTPPatchMacro"
)

@attached(peer, names: prefixed(_route_))
public macro HTTP(_ method: HTTPRequest.Method, _ pathComponents: Any...) = #externalMacro(
    module: "VaporMacrosPlugin",
    type: "HTTPMethodMacro"
)
