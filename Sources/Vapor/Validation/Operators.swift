// MARK: && - Combine Validators

func && <L: _Validator, R: _Validator>(lhs: L, rhs: R) -> _ValidatorList<L.Input> where L.Input == R.Input {
    let list = _ValidatorList<L.Input>()
    list.extend(lhs)
    list.extend(rhs)
    return list
}

func && <R: _Validator>(lhs: _ValidatorList<R.Input>, rhs: R) -> _ValidatorList<R.Input> {
    let list = _ValidatorList<R.Input>()
    lhs.validators.forEach(list.extend)
    list.extend(rhs)
    return list
}

func && <L: _Validator>(lhs: L, rhs: _ValidatorList<L.Input>) -> _ValidatorList<L.Input> {
    let list = _ValidatorList<L.Input>()
    rhs.validators.forEach(list.extend)
    list.extend(lhs)
    return list
}

func && <I: _Validatable>(lhs: _ValidatorList<I>, rhs: _ValidatorList<I>) -> _ValidatorList<I> {
    let list = _ValidatorList<I>()
    lhs.validators.forEach(list.extend)
    rhs.validators.forEach(list.extend)
    return list
}

// MARK: || - Combine OR validators

public func || <L: _Validator, R: _Validator> (lhs: L, rhs: R) -> EitherValidator<L.Input> where L.Input == R.Input {
    return EitherValidator(lhs, rhs)
}

// MARK: ! - Invert Validator

public prefix func ! <V: _Validator>(validator: V) -> _Not<V.Input> {
    return _Not(validator)
}
