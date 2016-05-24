public class Gate<U> {
    var policies = [Policy]()

    public init(_ userType: U.Type = U.self) {}

    public func addPolicy<T>(to action: Action, a type: T.Type, voter: (object: T, user: U?) -> Bool?) {
        let ability = Ability(action: action, type: type)
        let policy = SpecificPolicy(ability: ability, voter: voter)
        policies.append(policy as Policy)
    }
    
    public func addPolicy<T>(to action: Action, a type: T.Type, voter: (user: U?) -> Bool?) {
        let ability = Ability(action: action, type: type)
        let policy = GeneralPolicy(ability: ability, voter: voter)
        policies.append(policy as Policy)
    }

    public func check<T>(if user: U?, can action: Action, this object: T) throws -> Bool {
        for policy in policies {
            if let vote = policy.vote(whether: user, may: action, this: object) {
                return vote
            }
        }

        return try check(if: user, can: action, a: object.dynamicType)
    }

    public func check<T>(if user: U?, can action: Action, a type: T.Type) throws -> Bool {
        for policy in policies {
            if let vote = policy.vote(whether: user, may: action, a: type) {
                return vote
            }
        }

        throw Abort.custom(
            status: .internalServerError,
            message: "Tried to check if user was allowed to \(action) a \(type), but no policy existed."
        )
    }

    public func check<T>(if user: U?, can action: Action, an type: T.Type) throws -> Bool {
        return try check(if: user, can: action, a: type)
    }

    public func check<T>(if user: U?, can action: Action, this object: T) throws {
        guard try check(if: user, can: action, this: object) else {
            throw Abort.custom(status: .unauthorized, message: "User is not allowed to \(action) a \(object)")
        }
    }

    public func check<T>(if user: U?, can action: Action, a type: T.Type) throws {
        guard try check(if: user, can: action, a: type) else {
            throw Abort.custom(status: .unauthorized, message: "User is not allowed to \(action) a \(type)")
        }
    }

    public func check<T>(if user: U?, can action: Action, an type: T.Type) throws {
        try check(if: user, can: action, a: type) as Void
    }
}
