/**
 * This protocol is used to mark a User model
 * as an "authorizable" model. Unlike all other models.
 * And it comes with a handy method for checking a permission.
 * So you can write `if user.can(.update, this: post) { ... }`
 */
public protocol Authorizable {
    var gate: Gate<Self> { get }
    func can<T>(_ action: Action, this model: T) -> Bool
    func cannot<T>(_ action: Action, this model: T) -> Bool
}

public extension Authorizable {
    public func can<T>(_ action: Action, this model: T) throws -> Bool {
        return try gate.check(if: self, can: action, this: model)
    }

    public func cannot<T>(_ action: Action, this model: T) throws -> Bool {
        return try !self.can(action, this: model)
    }
}
