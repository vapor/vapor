import Foundation

/// A parameter and its resolved value.
public struct ParameterValue {
    /// The parameter type.
    let slug: [UInt8]

    /// The resolved value.
    let value: [UInt8]

    /// Create a new lazy parameter.
    init(slug: [UInt8], value: [UInt8]) {
        self.slug = slug
        self.value = value
    }
}
