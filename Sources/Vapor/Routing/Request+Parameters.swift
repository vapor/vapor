import Foundation

extension Request {
    /// Grabs the next parameter from the parameter bag.
    ///
    /// Note: the parameters _must_ be fetched in the order they
    /// appear in the path.
    ///
    /// For example GET /posts/:post_id/comments/:comment_id
    /// must be fetched in this order:
    ///
    ///     let post = try parameters.next(Post.self)
    ///     let comment = try parameters.next(Comment.self)
    ///
    public func next<P>(_ parameter: P.Type = P.self) throws -> P.ResolvedParameter
        where P: Parameter
    {
        guard parameters.count > 0 else {
            throw VaporError(identifier: "insufficientParameters", reason: "Insufficient parameters")
        }

        let current = parameters[0]
        guard current.slug == Data(P.uniqueSlug.utf8) else {
            throw VaporError(identifier: "invalidParameterType", reason: "Invalid parameter type. Expected \(P.self) got \(current.slug)")
        }

        let item = try P.make(for: String(data: current.value, encoding: .utf8) ?? "", in: self)
        parameters = Array(parameters.dropFirst())
        return item
    }

    /// Infer requested type where the resolved parameter is the parameter type.
    public func next<P>() throws -> P
        where P: Parameter, P.ResolvedParameter == P
    {
        return try self.next(P.self)
    }
}
