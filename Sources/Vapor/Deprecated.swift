extension Request {
    /// Use `Request.parameters`.
    @available(*, deprecated, renamed: "parameters.next")
    public func parameter<P>() throws -> P
        where P: Parameter, P.ResolvedParameter == P
    {
        return try parameters.next(P.self)
    }

    /// Use `Request.parameters`.
    @available(*, deprecated, renamed: "parameters.next")
    public func parameter<P>(_ parameter: P.Type) throws -> P.ResolvedParameter
        where P: Parameter
    {
        return try parameters.next(P.self)
    }
}
