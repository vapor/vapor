import Foundation

/// A parameter and its resolved value.
internal struct ParameterValue {
    /// The parameter type.
    internal let slug: Data

    /// The resolved value.
    internal let value: Data

    /// Create a new lazy parameter.
    internal init(slug: Data, value: Data) {
        self.slug = slug
        self.value = value
    }
}
