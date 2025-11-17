import Foundation

public protocol RoutesBuilder {
    func add(_ route: Route)
}

extension Foundation.UUID: @retroactive Swift.LosslessStringConvertible {
    public init?(_ description: String) {
        self.init(uuidString: description)
    }
}
