/**
 * This protocol is used to mark a User model
 * as an "authorizable" model. Unlike all other models.
 * And it comes with a handy method for checking a permission.
 * So you can write `if user.can(.update, this: post) { ... }`
 */
public protocol Authorizable: Model {
    func can(_ action: Ability.Action, this model: Model) -> Bool
    func cannot(_ action: Ability.Action, this model: Model) -> Bool
}

public extension Authorizable {
    public func can(_ action: Ability.Action, this model: Model) -> Bool {
        return Gate.check(if: self, can: action, this: model)
    }

    public func cannot(_ action: Ability.Action, this model: Model) -> Bool {
        return !self.can(action, this: model)
    }
}
