// Placeholder until Fluent is added as a dependency
public protocol Model {}

public class Gate {
    static var defaultVote = false
    static var policies = [Policy]()
    
    public static func addPolicy<T: Model>(to action: Action, a  model:  T.Type, voter:  (T, Authorizable?) -> Bool?) {
        let ability = Ability(action: action, model: model)
        let policy = AnyPolicy(ability: ability, voter: voter)
        policies.append(policy as Policy)
    }
    
    public static func check<T: Model>(if user: Authorizable?, can action: Action, this model: T) -> Bool {
        for policy in policies {
            if let vote = policy.vote(whether: user, may: action, this: model) {
                return vote
            }
        }
        
        return defaultVote
    }
    
    public static func check<T: Model>(if user: Authorizable?, can action: Action, this model: T) throws {
        guard check(if: user, can: action, this: model) else {
            throw Abort.custom(status: .unauthorized, message: "User is not allowed to \(action) a \(model)")
        }
    }
}
