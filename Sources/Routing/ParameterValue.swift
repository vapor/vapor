import Foundation

/// A parameter and its resolved value.
public struct ParameterValue {
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
