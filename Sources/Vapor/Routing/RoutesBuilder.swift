import Foundation

public protocol RoutesBuilder {
    @available(*, deprecated, message: "Use SendableRoute instead")
    func add(_ route: Route)
    func add(_ route: SendableRoute)
}

extension RoutesBuilder {
    // Required not to break the API for most people
    @available(*, deprecated, message: "Use SendableRoute instead")
    func add(_ route: SendableRoute) {
        self.add(Route(sendableRoute: route))
    }
}

extension UUID: LosslessStringConvertible {
    public init?(_ description: String) {
        self.init(uuidString: description)
    }
}
