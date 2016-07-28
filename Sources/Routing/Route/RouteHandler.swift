public enum RouteHandler<Output> {
    case `static`(Output?)
    case dynamic((Routeable, ParametersContainer) -> (Output?))
}
