// Placeholder until Fluent is added as a dependency
public protocol Model {}

public class Gate {
    static var defaultVote = false
    static var abilities = [(Ability, Voter)]()
    
    public typealias Voter = (Model, Authorizable?) -> Bool?
    
    public static func addAbility(to action: Ability.Action, a model: Model.Type, voter: Voter) {
        let ability = Ability(action: action, model: model)
        
        abilities.append((ability, voter))
    }
    
    public static func check(if user: Authorizable?, can action: Ability.Action, this model: Model) -> Bool {
        let abilityToCheck = Ability(action: action, model: model.dynamicType)
        
        for (ability, voter) in abilities where ability == abilityToCheck {
            if let vote = voter(model, user) {
                return vote
            }
        }
        
        return defaultVote
    }
    
    public static func check(if user: Authorizable?, can action: Ability.Action, this model: Model) throws {
        guard check(if: user, can: action, this: model) else {
            throw Abort.custom(status: .unauthorized, message: "User is not allowed to \(action) a \(model)")
        }
    }
}
