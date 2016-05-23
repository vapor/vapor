protocol Policy {
    func vote<U>(whether: U?, may: Action, this: Any) -> Bool?
}

struct AnyPolicy<T, U>: Policy {
    let ability: Ability<T>
    let voter: (T, U?) -> Bool?

    func vote<V>(whether user: V?, may action: Action, this model: Any) -> Bool? {
        guard let user = user as? U?, let model = model as? T
              where action == ability.action else {
            return nil
        }

        return voter(model, user)
    }
}
