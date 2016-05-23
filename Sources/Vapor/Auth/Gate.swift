public class Gate<U> {
    var policies = [Policy]()

    public init(_ userType: U.Type = U.self) {}

    public func addPolicy<T>(to action: Action, a model: T.Type, voter: (T, U?) -> Bool?) {
        let ability = Ability(action: action, model: model)
        let policy = AnyPolicy(ability: ability, voter: voter)
        policies.append(policy as Policy)
    }

    public func check<T>(if user: U?, can action: Action, this model: T) throws -> Bool {
        for policy in policies {
            if let vote = policy.vote(whether: user, may: action, this: model) {
                return vote
            }
        }

        throw Abort.custom(
            status: .internalServerError,
            message: "Tried to check if user was allowed to \(action) a \(model), but no policy existed."
        )
    }

    public func check<T>(if user: U?, can action: Action, this model: T) throws {
        guard try check(if: user, can: action, this: model) else {
            throw Abort.custom(status: .unauthorized, message: "User is not allowed to \(action) a \(model)")
        }
    }
}
