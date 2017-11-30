public protocol ServiceType {
    /// If true, the `makeService` method will only
    /// be called once and the service instance will be cached.
    /// Defaults to true.
    static var serviceIsSingleton: Bool { get }

    /// An array of protocols (or types) that this
    /// service conforms to. 
    ///     ex. when `container.make(X.self)`
    ///     is called, all services that support `X`
    ///     will be considered.
    static var serviceSupports: [Any.Type] { get }

    /// Creates a new instance of the service
    /// Using the service container.
    static func makeService(for context: Context) throws -> Self?
}

extension ServiceType {
    public static var serviceIsSingleton: Bool {
        return true
    }
}
