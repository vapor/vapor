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

    /// Gets all parameters from the parameter bag that have the
    /// associated slug.
    ///
    ///     let ids: [String] = request.parameters["id"]
    ///
    /// - parameters:
    ///   - slug: The slug for the value(s) to fetch.
    ///
    /// - returns: All associated parameter values for the slug.
    public subscript (_ slug: String) -> [String] {
        return self.request._parameters[slug]
    }
    
    /// Gets all parameters from the parameter bag that have the
    /// associated slug and resolves them using the connected request
    /// as the container.
    ///
    ///     let comments: [Comments.ResolvedParameter] = request.parameters["comment", as: Comment.self]
    ///
    /// - parameters:
    ///   - slug: The slug for the value(s) to fetch.
    ///
    /// - returns: All associated resolved parameter values for the slug.
    public subscript <P>(_ slug: String, as type: P.Type) -> [P.ResolvedParameter] where P: Parameter {
        return self.request._parameters[slug, as: P.self, on: self.request]
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
