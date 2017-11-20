import Async
import HTTP

/// A bag for holding parameters resolved during router
///
/// [Learn More →](https://docs.vapor.codes/3.0/routing/parameters/)
public struct ParameterBag {
    /// The parameters, not yet resolved
    /// so that the `.next()` method can throw any errors.
    var parameters: [LazyParameter]
    let request: Request

    /// Create a new parameters bag
    public init(request: Request) {
        self.parameters = []
        self.request = request
    }

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
    public mutating func next<P>(_ parameter: P.Type = P.self) throws -> P.ResolvedParameter
        where P: Parameter
    {
        guard parameters.count > 0 else {
            throw RoutingError(.insufficientParameters)
        }

        let current = parameters[0]
        guard current.slug == P.uniqueSlug else {
            throw RoutingError(.invalidParameterType(
                actual: current.slug,
                expected: P.uniqueSlug
            ))
        }

        let item = try P.make(for: current.value, in: request)
        parameters = Array(parameters.dropFirst())
        return item
    }

    /// Infer requested type where the resolved parameter is the parameter type.
    public mutating func next<P>() throws -> P
        where P: Parameter, P.ResolvedParameter == P
    {
        return try self.next(P.self)
    }
}

/// A parameter and its resolved value.
internal struct LazyParameter {
    /// The parameter type.
    let slug: String

    /// The resolved value.
    let value: String

    /// Create a new lazy parameter.
    init(slug: String, value: String) {
        self.slug = slug
        self.value = value
    }
}
