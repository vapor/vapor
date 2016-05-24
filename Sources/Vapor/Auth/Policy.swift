protocol Policy {
    func vote<User>(whether: User?, may: Action, this: Any) -> Bool?
    func vote<User>(whether: User?, may: Action, a: Any.Type) -> Bool?
}

struct SpecificPolicy<Object, User>: Policy {
    let ability: Ability<Object>
    let voter: (object: Object, user: User?) -> Bool?

    func vote<V>(whether user: V?, may action: Action, this object: Any) -> Bool? {
        guard let user = user as? User?, let object = object as? Object
              where action == ability.action else {
            return nil
        }

        return voter(object: object, user: user)
    }

    func vote<V>(whether user: V?, may action: Action, a type: Any.Type) -> Bool? {
        return nil
    }
}

struct GeneralPolicy<Object, User>: Policy {
    let ability: Ability<Object>
    let voter: (user: User?) -> Bool?

    func vote<V>(whether user: V?, may action: Action, this object: Any) -> Bool? {
        return nil
    }

    func vote<V>(whether user: V?, may action: Action, a type: Any.Type) -> Bool? {
        guard let user = user as? User?
            where type is Object.Type && action == ability.action else {
                return nil
        }

        return voter(user: user)
    }
}
