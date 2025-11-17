import Foundation

public protocol RoutesBuilder {
    func add(_ route: Route)
}

// I think we can have a better way by introducing a `PathParameter` protocol that strings and some types can conform to
// That way we don't need this and we can restrict the macros to take `String` or `Int.self`, `String.self`, `UUID.self` etc instead of `Any`
// This would also help Fluent add conformances
#warning("Find a better way")
extension Foundation.UUID: @retroactive Swift.LosslessStringConvertible {
    public init?(_ description: String) {
        self.init(uuidString: description)
    }
}
