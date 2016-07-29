public enum RouteHandler<Output> {
    case `static`(Output?)
    case dynamic(([String], ParametersContainer) -> (Output?))
}
