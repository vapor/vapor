
// MARK: Not

/**
 Inverts the logic of a Validator
 
     !validatorToInvert
 
 - parameter rhs: validator to invert

 - returns: Not<V> representing an inversion of the input Validator
 */
public prefix func ! <V: Validator> (rhs: V) -> Not<V> {
    return Not(rhs)
}


/**
 Inverts the logic of a ValidationSuite

     !ValidationSuiteToInvert.self

 - parameter rhs: validation suite to invert

 - returns: Not<V> representing an inversion of the input ValidationSuite
 */
public prefix func ! <V: ValidationSuite> (rhs: V.Type) -> Not<V> {
    return Not(rhs)
}

// MARK: Or

/**
 Combine two validators using a logical ||
 If either succeeds, the validation will pass

 - parameter lhs: left validator will be run first
 - parameter rhs: right validator, will be used if left fails

 - returns: Or<V,U> representing the || combination of the two validators
 */
public func || <V: Validator, U: Validator where V.InputType == U.InputType> (lhs: V, rhs: U) -> Or<V, U> {
    return Or(lhs, rhs)
}

/**
 Combine two validators using a logical ||
 If either succeeds, the validation will pass

 - parameter lhs: left validator. will be run first
 - parameter rhs: right validation suite. will be used if lhs fails

 - returns: Or<V,U> representing the || combination of the two validators
 */
public func || <V: Validator, U: ValidationSuite where V.InputType == U.InputType> (lhs: V, rhs: U.Type) -> Or<V, U> {
    return Or(lhs, rhs)
}

/**
 Combine two validators using a logical ||.
 If either succeeds, the validation will pass

 - parameter lhs: left validation suite. will be run first
 - parameter rhs: right validator. will be used if lhs fails

 - returns: Or<V,U> representing the || combination of the two validators
 */
public func || <V: ValidationSuite, U: Validator where V.InputType == U.InputType> (lhs: V.Type, rhs: U) -> Or<V, U> {
    return Or(lhs, rhs)
}

/**
 Combine two validators using a logical ||
 If either succeeds, the validation will pass

 - parameter lhs: left validation suite. will be run first
 - parameter rhs: right validation suite. will be used if lhs fails

 - returns: Or<V,U> representing the || combination of the two validators
 */
public func || <V: ValidationSuite, U: ValidationSuite where V.InputType == U.InputType> (lhs: V.Type, rhs: U.Type) -> Or<V, U> {
    return Or(lhs, rhs)
}

// MARK: And

/**
 Combine two validators using a logical &&
 Both must succeed for validation to pass

 - parameter lhs: left validator. will run first
 - parameter rhs: right validator. will run if lhs succeeds

 - returns: an And<V,U> object representing the concatination of the two validators
 */
public func && <V: Validator, U: Validator where V.InputType == U.InputType> (lhs: V, rhs: U) -> And<V, U> {
    return And(lhs, rhs)
}

/**
 Combine two validators using a logical &&
 Both must succeed for validation to pass

 - parameter lhs: left validator. will run first
 - parameter rhs: right validation suite. will run if lhs succeeds

 - returns: an And<V,U> object representing the concatination of the two validators
 */
public func && <V: Validator, U: ValidationSuite where V.InputType == U.InputType> (lhs: V, rhs: U.Type) -> And<V, U> {
    return And(lhs, rhs)
}

/**
 Combine two validators using a logical &&
 Both must succeed for validation to pass

 - parameter lhs: left validation suite. will run first
 - parameter rhs: right validator. will run if lhs succeeds

 - returns: an And<V,U> object representing the concatination of the two validators
 */
public func && <V: ValidationSuite, U: Validator where V.InputType == U.InputType> (lhs: V.Type, rhs: U) -> And<V, U> {
    return And(lhs, rhs)
}

/**
 Combine two validators using a logical &&
 Both must succeed for validation to pass

 - parameter lhs: left validation suite. will run first
 - parameter rhs: right validation suite. will run if lhs succeeds

 - returns: an And<V,U> object representing the concatination of the two validators
 */
public func && <V: ValidationSuite, U: ValidationSuite where V.InputType == U.InputType> (lhs: V.Type, rhs: U.Type) -> And<V, U> {
    return And(lhs, rhs)
}

// MARK: Combine

/**
 Combine two validators using a logical &&
 Both must succeed for validation to pass

 - parameter lhs: left validator. will run first
 - parameter rhs: right validator. will run if lhs succeeds

 - returns: an And<V,U> object representing the concatination of the two validators
 */
public func + <V: Validator, U: Validator where V.InputType == U.InputType>(lhs: V, rhs: U) -> And<V, U> {
    return And(lhs, rhs)
}

/**
 Combine two validators using a logical &&
 Both must succeed for validation to pass

 - parameter lhs: left validator. will run first
 - parameter rhs: right validation suite. will run if lhs succeeds

 - returns: an And<V,U> object representing the concatination of the two validators
 */
public func + <V: Validator, U: ValidationSuite where V.InputType == U.InputType>(lhs: V, rhs: U.Type) -> And<V, U> {
    return And(lhs, rhs)
}

/**
 Combine two validators using a logical &&
 Both must succeed for validation to pass

 - parameter lhs: left validation suite. will run first
 - parameter rhs: right validator. will run if lhs succeeds

 - returns: an And<V,U> object representing the concatination of the two validators
 */
public func + <V: ValidationSuite, U: Validator where V.InputType == U.InputType>(lhs: V.Type, rhs: U) -> And<V, U> {
    return And(lhs, rhs)
}

/**
 Combine two validators using a logical &&
 Both must succeed for validation to pass

 - parameter lhs: left validation suite. will run first
 - parameter rhs: right validation suite. will run if lhs succeeds

 - returns: an And<V,U> object representing the concatination of the two validators
 */
public func + <V: ValidationSuite, U: ValidationSuite where V.InputType == U.InputType>(lhs: V.Type, rhs: U.Type) -> And<V, U> {
    return And(lhs, rhs)
}
