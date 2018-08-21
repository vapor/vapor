/// Helper for accessing route parameters from an HTTP request.
///
///     let id = try req.parameters.next(Int.self)
///
public struct ParametersContainer {
    /// Private `Request`.
    private let request: Request

    /// The `ParameterValue`s that this request collected as it was being routed.
    public var values: [ParameterValue] {
        return request._parameters.values
    }

    /// Creates a new `ParametersContainer`. Use `Request.parameters`.
    init(_ request: Request) {
        self.request = request
    }

    /// Gets the raw parameter values from the request URI
    /// that match a given parameter type slug.
    ///
    ///     let ids = request.parameters.rawValues(for: User.self)
    ///     print(ids) // [String]
    ///
    public func rawValues<P>(for paramter: P.Type) -> [String] where P: Parameter {
        return self.values.filter { value in value.slug == paramter.routingSlug }.map { $0.value }
    }
    
    /// Grabs the next parameter from the parameter bag.
    ///
    ///     let id = try req.parameters.next(Int.self)
    ///
    /// - note: the parameters _must_ be fetched in the order they appear in the path.
    ///
    /// For example GET /posts/:post_id/comments/:comment_id must be fetched in this order:
    ///
    ///     let post = try req.parameters.next(Post.self)
    ///     let comment = try req.parameters.next(Comment.self)
    ///
    public func next<P>() throws -> P
        where P: Parameter, P.ResolvedParameter == P
    {
        return try next(P.self)
    }

    /// Grabs the next parameter from the parameter bag.
    ///
    ///     let id = try req.parameters.next(Int.self)
    ///
    /// - note: the parameters _must_ be fetched in the order they appear in the path.
    ///
    /// For example GET /posts/:post_id/comments/:comment_id must be fetched in this order:
    ///
    ///     let post = try req.parameters.next(Post.self)
    ///     let comment = try req.parameters.next(Comment.self)
    ///
    public func next<P>(_ parameter: P.Type) throws -> P.ResolvedParameter
        where P: Parameter
    {
        return try request._parameters.next(P.self, on: request)
    }
}
