struct ServiceExtension<T> {
    let closure: (inout T, Application) throws -> Void
    
    init(closure: @escaping (inout T, Application) throws -> Void) {
        self.closure = closure
    }
    
    func serviceExtend(_ instance: inout T, _ app: Application) throws {
        try closure(&instance, app)
    }
}
