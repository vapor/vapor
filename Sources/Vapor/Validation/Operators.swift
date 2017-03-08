// MARK: && - Combine Validators

func && <L: Validator, R: Validator>(lhs: L, rhs: R) -> ValidatorList<L.Input> where L.Input == R.Input {
    let list = ValidatorList<L.Input>()
    list.extend(lhs)
    list.extend(rhs)
    return list
}

func && <R: Validator>(lhs: ValidatorList<R.Input>, rhs: R) -> ValidatorList<R.Input> {
    let list = ValidatorList<R.Input>()
    lhs.validators.forEach(list.extend)
    list.extend(rhs)
    return list
}

func && <L: Validator>(lhs: L, rhs: ValidatorList<L.Input>) -> ValidatorList<L.Input> {
    let list = ValidatorList<L.Input>()
    rhs.validators.forEach(list.extend)
    list.extend(lhs)
    return list
}

func && <I: Validatable>(lhs: ValidatorList<I>, rhs: ValidatorList<I>) -> ValidatorList<I> {
    let list = ValidatorList<I>()
    lhs.validators.forEach(list.extend)
    rhs.validators.forEach(list.extend)
    return list
}

// MARK: || - Combine OR validators

public func || <L: Validator, R: Validator> (lhs: L, rhs: R) -> Either<L.Input> where L.Input == R.Input {
    return Either(lhs, rhs)
}

// MARK: ! - Invert Validator

public prefix func ! <V: Validator>(validator: V) -> Not<V.Input> {
    return Not(validator)
}
