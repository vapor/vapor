import Foundation

public protocol RoutesBuilder {
    func add(_ route: Route) async
}

extension Foundation.UUID: Swift.LosslessStringConvertible {
    public init?(_ description: String) {
        self.init(uuidString: description)
    }
}
