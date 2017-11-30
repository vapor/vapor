import Async
import Foundation
import HTTP
import Service

/// A bag for holding parameters resolved during router
///
/// [Learn More →](https://docs.vapor.codes/3.0/routing/parameters/)
public protocol ParameterContainer: class {
    /// An array of parameters
    typealias Parameters = [ParameterValue]

    /// The parameters, not yet resolved
    /// so that the `.next()` method can throw any errors.
    var parameters: Parameters { get set }
}

/// MARK: Next

extension Container where Self: ParameterContainer {
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
    public func parameter<P>(_ parameter: P.Type = P.self) throws -> P.ResolvedParameter
        where P: Parameter
    {
        guard parameters.count > 0 else {
            throw RoutingError(identifier: "insufficientParameters", reason: "Insufficient parameters")
        }

        let current = parameters[0]
        guard current.slug == Data(P.uniqueSlug.utf8) else {
            throw RoutingError(
                identifier: "invalidParameterType",
                reason: "Invalid parameter type. Expected \(P.self) got \(current.slug)"
            )
        }

        guard let string = String(data: current.value, encoding: .utf8) else {
            throw RoutingError(
                identifier: "convertString",
                reason: "Could not convert the parameter value to a UTF-8 string."
            )
        }

        let item = try P.make(for: string, using: self)
        parameters = Array(parameters.dropFirst())
        return item
    }

    /// Infer requested type where the resolved parameter is the parameter type.
    public func parameter<P>() throws -> P
        where P: Parameter, P.ResolvedParameter == P
    {
        return try self.parameter(P.self)
    }
}
