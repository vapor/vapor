protocol Policy {
    func vote(whether: Authorizable?, may: Action, this: Model) -> Bool?
}

struct AnyPolicy<T: Model>: Policy {
    let ability: Ability<T>
    let voter: (T, Authorizable?) -> Bool?

    func vote(whether user: Authorizable?, may action: Action, this model: Model) -> Bool? {
        guard let model = model as? T where action == ability.action else {
            return nil
        }

        return voter(model, user)
    }
}
