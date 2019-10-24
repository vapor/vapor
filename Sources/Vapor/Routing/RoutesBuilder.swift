public protocol RoutesBuilder {
    func add(_ route: Route)
}

extension UUID: LosslessStringConvertible {
    public init?(_ description: String) {
        self.init(uuidString: description)
    }
}
