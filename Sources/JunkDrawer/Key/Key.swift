/// A model property containing the
/// Swift key path for accessing it.
public struct Key {
    /// The Swift keypath
    public var path: AnyKeyPath

    /// The properties type.
    /// Storing this as any since we lost
    /// the type info converting to AnyKeyPAth
    public var type: Any.Type

    /// True if the property on the model is optional.
    /// The `type` is the Wrapped type if this is true.
    public var isOptional: Bool

    /// Create a new model key.
    internal init<T>(path: AnyKeyPath, type: T.Type, isOptional: Bool) {
        self.path = path
        self.type = type
        self.isOptional = isOptional
    }
}
