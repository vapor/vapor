protocol Policy {
    func vote<U: Authorizable>(whether: U?, may: Action, this: Model) -> Bool?
}

struct AnyPolicy<T: Model, U: Authorizable>: Policy {
    let ability: Ability<T>
    let voter: (T, U?) -> Bool?

    func vote<V: Authorizable>(whether user: V?, may action: Action, this model: Model) -> Bool? {
        guard let user = user as? U?, let model = model as? T
              where action == ability.action else {
            return nil
        }

        return voter(model, user)
    }
}
