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
    public func can<T>(_ action: Action, this object: T) throws -> Bool {
        return try gate.check(if: self, can: action, this: object)
    }

    public func cannot<T>(_ action: Action, this object: T) throws -> Bool {
        return try !self.can(action, this: object)
    }
    
    public func can<T>(_ action: Action, a type: T.Type) throws -> Bool {
        return try gate.check(if: self, can: action, a: type)
    }
    
    public func cannot<T>(_ action: Action, a type: T.Type) throws -> Bool {
        return try !self.can(action, a: type)
    }
    
    public func can<T>(_ action: Action, an type: T.Type) throws -> Bool {
        return try self.can(action, a: type)
    }
    
    public func cannot<T>(_ action: Action, an type: T.Type) throws -> Bool {
        return try self.cannot(action, a: type)
    }
}
