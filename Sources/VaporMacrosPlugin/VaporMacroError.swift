enum MacroError: Error, CustomStringConvertible {
    case notAFunction
    case missingArguments
    case missingRequest
    case invalidNumberOfParameters(Int, Int)

    var description: String {
        switch self {
        case .notAFunction:
            "@GET can only be applied to functions"
        case .missingArguments:
            "@GET requires path components as arguments"
        case .missingRequest:
            "The first parameter to the function must be a Request"
        case .invalidNumberOfParameters(let macro, let function):
            "The macro defines \(macro) arguments, but the function has \(function)"
        }
    }
}
