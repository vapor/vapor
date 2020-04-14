public protocol RoutesBuilder {
    var defaultMaxBodySize: Int? { get }

    func add(_ route: Route)
}

extension RoutesBuilder {
    public var defaultMaxBodySize: Int? { 1_000_000 }
}

extension UUID: LosslessStringConvertible {
    public init?(_ description: String) {
        self.init(uuidString: description)
    }
}
