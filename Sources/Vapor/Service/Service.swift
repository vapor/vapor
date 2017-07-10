public protocol Service {
    /// This service's name.
    /// Used to disambiguate services if multiple
    /// conforming ot the requested interface are available.
    static var name: String { get }

    /// Creates a new instance of the service
    /// Using the service container.
    static func make(for drop: Droplet) throws -> Self?
}

extension Service {
    /// Default name is class name lowercased.
    public static var name: String {
        return "\(self)"
            .splitUppercaseCharacters()
            .joined(separator: "-")
            .lowercased()
    }
}
