/// A bag for holding parameters resolved during router
public struct ParameterBag {
    /// The parameters, not yet resolved
    /// so that the `.next()` method can throw any errors.
    var parameters: [LazyParameter]

    /// Create a new parameters bag
    public init() {
        self.parameters = []
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
    public mutating func next<P: Parameter>(_ parameter: P.Type = P.self) throws -> P {
        guard parameters.count > 0 else {
            throw Error(.insufficientParameters)
        }
        let current = parameters[0]

        guard current.type == P.self else {
            throw Error(.invalidParameterType(
                actual: current.type,
                expected: P.self
            ))
        }

        let item = try current.type.make(for: current.value)
        guard let cast = item as? P else {
            throw Error(.invalidParameterType(
                actual: type(of: item),
                expected: P.self
            ))
        }

        parameters = Array(parameters.dropFirst())

        return cast
    }
}

/// A parameter and its resolved value.
internal struct LazyParameter {
    /// The parameter type.
    let type: Parameter.Type

    /// The resolved value.
    let value: String

    /// Create a new lazy parameter.
    init(type: Parameter.Type, value: String) {
        self.type = type
        self.value = value
    }
}
