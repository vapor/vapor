import HTTPTypes
import Vapor

@attached(extension, conformances: RouteCollection, names: named(boot(routes:)))
public macro Controller() = #externalMacro(
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

@attached(peer, names: arbitrary)
public macro RouteRegistration() = #externalMacro(
    module: "VaporMacrosPlugin",
    type: "RouteRegistrationMacro",
)