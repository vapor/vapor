import Async
import Foundation
import HTTP
import Service

/// A bag for holding parameters resolved during router
///
/// [Learn More →](https://docs.vapor.codes/3.0/routing/parameters/)
public final class ParameterContainer {
    /// The parameters, not yet resolved
    /// so that the `.next()` method can throw any errors.
    var values: [ParameterValue]

    /// The container we are using to initialize parameters.
    weak var container: Container?

    /// Create a new parameters bag.
    public init(container: Container) {
        values = []
        self.container = container
    }
}

/// MARK: Next

extension ParameterContainer {
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
        guard values.count > 0 else {
            throw RoutingError(identifier: "insufficientParameters", reason: "Insufficient parameters")
        }

        let current = values[0]
        guard current.slug == Data(P.uniqueSlug.utf8) else {
            throw RoutingError(
                identifier: "invalidParameterType",
                reason: "Invalid parameter type. Expected \(P.self) got \(current.slug)"
            )
        }

        guard let container = self.container else {
            throw RoutingError(
                identifier: "noContainer",
                reason: "The container has deallocated."
            )
        }

        guard let string = String(data: current.value, encoding: .utf8) else {
            throw RoutingError(
                identifier: "convertString",
                reason: "Could not convert the parameter value to a UTF-8 string."
            )
        }

        let item = try P.make(for: string, using: container)
        values = Array(values.dropFirst())
        return item
    }

    /// Infer requested type where the resolved parameter is the parameter type.
    public func next<P>() throws -> P
        where P: Parameter, P.ResolvedParameter == P
    {
        return try self.next(P.self)
    }
}
