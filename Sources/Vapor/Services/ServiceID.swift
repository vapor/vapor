/// Simple wrapper around an `Any.Type` to provide better debug information.
struct ServiceID: Hashable, Equatable, CustomStringConvertible {
    /// See `Equatable`.
    static func ==(lhs: ServiceID, rhs: ServiceID) -> Bool {
        return lhs.type == rhs.type
    }
    
    /// See `Hashable`.
    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(type))
    }
    
    /// The wrapped type.
    internal let type: Any.Type
    
    /// See `CustomStringConvertible`
    var description: String {
        return "\(type)"
    }
    
    /// Creates a new `ServiceID`, wrapping the supplied type.
    init(_ type: Any.Type) {
        self.type = type
    }
}
