import Async
import Foundation
import HTTP

/// A bag for holding parameters resolved during router
///
/// [Learn More →](https://docs.vapor.codes/3.0/routing/parameters/)
public protocol ParameterBag: class {
    /// The parameters, not yet resolved
    /// so that the `.next()` method can throw any errors.
    var parameters: [ResolvedParameter] { get set }
}

/// A parameter and its resolved value.
public struct ResolvedParameter {
    /// The parameter type.
    public let slug: Data

    /// The resolved value.
    public let value: Data

    /// Create a new lazy parameter.
    public init(slug: Data, value: Data) {
        self.slug = slug
        self.value = value
    }
}
