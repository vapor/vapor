protocol Policy {
    func vote<U>(whether: U?, may: Action, this: Any) -> Bool?
    func vote<U>(whether: U?, may: Action, a: Any.Type) -> Bool?
}

struct SpecificPolicy<T, U>: Policy {
    let ability: Ability<T>
    let voter: (object: T, user: U?) -> Bool?

    func vote<V>(whether user: V?, may action: Action, this object: Any) -> Bool? {
        guard let user = user as? U?, let object = object as? T
              where action == ability.action else {
            return nil
        }

        return voter(object: object, user: user)
    }

    func vote<V>(whether user: V?, may action: Action, a type: Any.Type) -> Bool? {
        return nil
    }
}

struct GeneralPolicy<T, U>: Policy {
    let ability: Ability<T>
    let voter: (user: U?) -> Bool?

    func vote<V>(whether user: V?, may action: Action, this object: Any) -> Bool? {
        return nil
    }

    func vote<V>(whether user: V?, may action: Action, a type: Any.Type) -> Bool? {
        guard let user = user as? U?
            where type is T.Type && action == ability.action else {
                return nil
        }

        return voter(user: user)
    }
}
