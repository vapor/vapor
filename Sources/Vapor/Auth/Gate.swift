public class Gate<User> {
    var policies = [Policy]()

    public init(_ userType: User.Type = User.self) {}

    public func addPolicy<Object>(to action: Action, a type: Object.Type, voter: (object: Object, user: User?) -> Bool?) {
        let ability = Ability(action: action, type: type)
        let policy = SpecificPolicy(ability: ability, voter: voter)
        policies.append(policy as Policy)
    }

    public func addPolicy<Object>(to action: Action, a type: Object.Type, voter: (user: User?) -> Bool?) {
        let ability = Ability(action: action, type: type)
        let policy = GeneralPolicy(ability: ability, voter: voter)
        policies.append(policy as Policy)
    }

    public func check<Object>(if user: User?, can action: Action, this object: Object) throws -> Bool {
        for policy in policies {
            if let vote = policy.vote(whether: user, may: action, this: object) {
                return vote
            }
        }

        return try check(if: user, can: action, a: object.dynamicType)
    }

    public func check<Object>(if user: User?, can action: Action, a type: Object.Type) throws -> Bool {
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

    public func check<Object>(if user: User?, can action: Action, an type: Object.Type) throws -> Bool {
        return try check(if: user, can: action, a: type)
    }

    public func ensure<Object>(that user: User?, can action: Action, this object: Object) throws {
        guard try check(if: user, can: action, this: object) else {
            throw Abort.custom(status: .unauthorized, message: "User is not allowed to \(action) a \(object)")
        }
    }

    public func ensure<Object>(that user: User?, can action: Action, a type: Object.Type) throws {
        guard try check(if: user, can: action, a: type) else {
            throw Abort.custom(status: .unauthorized, message: "User is not allowed to \(action) a \(type)")
        }
    }

    public func ensure<Object>(that user: User?, can action: Action, an type: Object.Type) throws {
        try ensure(that: user, can: action, a: type)
    }
}
