
// MARK: Not

public prefix func ! <V: Validator> (rhs: V) -> Not<V> {
    return Not(rhs)
}
public prefix func ! <V: ValidationSuite> (rhs: V.Type) -> Not<V> {
    return Not(rhs)
}

// MARK: Or

public func || <V: Validator, U: Validator where V.InputType == U.InputType> (lhs: V, rhs: U) -> Or<V, U> {
    return Or(lhs, rhs)
}

public func || <V: Validator, U: ValidationSuite where V.InputType == U.InputType> (lhs: V, rhs: U.Type) -> Or<V, U> {
    return Or(lhs, rhs)
}

public func || <V: ValidationSuite, U: Validator where V.InputType == U.InputType> (lhs: V.Type, rhs: U) -> Or<V, U> {
    return Or(lhs, rhs)
}

public func || <V: ValidationSuite, U: ValidationSuite where V.InputType == U.InputType> (lhs: V.Type, rhs: U.Type) -> Or<V, U> {
    return Or(lhs, rhs)
}

// MARK: And

public func && <V: Validator, U: Validator where V.InputType == U.InputType> (lhs: V, rhs: U) -> And<V, U> {
    return And(lhs, rhs)
}

public func && <V: Validator, U: ValidationSuite where V.InputType == U.InputType> (lhs: V, rhs: U.Type) -> And<V, U> {
    return And(lhs, rhs)
}

public func && <V: ValidationSuite, U: Validator where V.InputType == U.InputType> (lhs: V.Type, rhs: U) -> And<V, U> {
    return And(lhs, rhs)
}

public func && <V: ValidationSuite, U: ValidationSuite where V.InputType == U.InputType> (lhs: V.Type, rhs: U.Type) -> And<V, U> {
    return And(lhs, rhs)
}

// MARK: Combine

public func + <V: Validator, U: Validator where V.InputType == U.InputType>(lhs: V, rhs: U) -> And<V, U> {
    return And(lhs, rhs)
}

public func + <V: Validator, U: ValidationSuite where V.InputType == U.InputType>(lhs: V, rhs: U.Type) -> And<V, U> {
    return And(lhs, rhs)
}

public func + <V: ValidationSuite, U: Validator where V.InputType == U.InputType>(lhs: V.Type, rhs: U) -> And<V, U> {
    return And(lhs, rhs)
}

public func + <V: ValidationSuite, U: ValidationSuite where V.InputType == U.InputType>(lhs: V.Type, rhs: U.Type) -> And<V, U> {
    return And(lhs, rhs)
}
