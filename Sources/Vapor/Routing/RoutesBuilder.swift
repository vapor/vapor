import Foundation

public protocol RoutesBuilder {
    @available(*, deprecated, message: "Use `SendableRoute` instead")
    func add(_ route: Route)
    func add(_ route: SendableRoute)
}

extension RoutesBuilder {
    func add(_ route: SendableRoute) {
        add(route.deprecatedRoute)
    }
}

extension UUID: LosslessStringConvertible {
    public init?(_ description: String) {
        self.init(uuidString: description)
    }
}
