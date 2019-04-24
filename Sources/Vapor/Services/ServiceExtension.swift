struct ServiceExtension<T> {
    public let closure: (inout T, Container) throws -> Void
    
    public init(closure: @escaping (inout T, Container) throws -> Void) {
        self.closure = closure
    }
    
    public func serviceExtend(_ instance: inout T, _ c: Container) throws {
        try closure(&instance, c)
    }
}
