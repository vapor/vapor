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