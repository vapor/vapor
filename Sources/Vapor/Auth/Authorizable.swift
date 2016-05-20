/**
 * This protocol is used to mark a User model
 * as an "authorizable" model. Unlike all other models.
 * And it comes with a handy method for checking a permission.
 * So you can write `if user.can(.update, this: post) { ... }`
 */
public protocol Authorizable: Model {
    var gate: Gate<Self> { get }
    func can(_ action: Action, this model: Model) -> Bool
    func cannot(_ action: Action, this model: Model) -> Bool
}

public extension Authorizable {
    public func can<T: Model>(_ action: Action, this model: T) throws -> Bool {
        return try gate.check(if: self, can: action, this: model)
    }

    public func cannot<T: Model>(_ action: Action, this model: T) throws -> Bool {
        return try !self.can(action, this: model)
    }
}
