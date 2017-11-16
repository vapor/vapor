import Async
import HTTP

/// A bag for holding parameters resolved during router
///
/// [For more information, see the documentation](https://docs.vapor.codes/3.0/routing/parameters/)
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
    public mutating func next<P: Parameter>(_ parameter: P.Type = P.self) -> Future<P> {
        let promise = Promise(P.self)

        if parameters.count > 0 {
            let current = parameters[0]

            if current.slug == P.uniqueSlug {
                do {
                    let item = try P.make(for: current.value, in: request)
                    parameters = Array(parameters.dropFirst())
                    item.chain(to: promise)
                } catch {
                    promise.fail(error)
                }
            } else {
                promise.fail(RoutingError(.invalidParameterType(
                    actual: current.slug,
                    expected: P.uniqueSlug
                )))
            }
        } else {
            promise.fail(RoutingError(.insufficientParameters))
        }

        return promise.future
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
