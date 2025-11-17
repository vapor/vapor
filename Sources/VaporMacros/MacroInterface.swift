import HTTPTypes

@attached(member, names: arbitrary)
@attached(memberAttribute)
public macro Controller() = #externalMacro(
    module: "VaporMacrosPlugin",
    type: "ControllerMacro"
)

@attached(peer, names: arbitrary)
public macro GET(_ pathComponents: Any...) = #externalMacro(
    module: "VaporMacrosPlugin",
    type: "HTTPGetMacro"
)

@attached(peer, names: arbitrary)
public macro POST(_ pathComponents: Any...) = #externalMacro(
    module: "VaporMacrosPlugin",
    type: "HTTPPostMacro"
)

@attached(peer, names: arbitrary)
public macro PUT(_ pathComponents: Any...) = #externalMacro(
    module: "VaporMacrosPlugin",
    type: "HTTPPutMacro"
)

@attached(peer, names: arbitrary)
public macro DELETE(_ pathComponents: Any...) = #externalMacro(
    module: "VaporMacrosPlugin",
    type: "HTTPDeleteMacro"
)

@attached(peer, names: arbitrary)
public macro PATCH(_ pathComponents: Any...) = #externalMacro(
    module: "VaporMacrosPlugin",
    type: "HTTPPatchMacro"
)

@attached(peer, names: arbitrary)
public macro HTTP(_ method: HTTPRequest.Method, _ pathComponents: Any...) = #externalMacro(
    module: "VaporMacrosPlugin",
    type: "HTTPMethodMacro"
)
