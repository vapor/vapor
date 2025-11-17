enum MacroError: Error, CustomStringConvertible {
    case notAFunction(String)
    case missingArguments(String)
    case missingRequest
    case invalidNumberOfParameters(String, Int, Int)

    var description: String {
        switch self {
        case .notAFunction(let macroName):
            "@\(macroName) can only be applied to functions"
        case .missingArguments(let macroName):
            "@\(macroName) requires path components as arguments"
        case .missingRequest:
            "The first parameter to the function must be a Request"
        case .invalidNumberOfParameters(let macroName, let macro, let function):
            "The @\(macroName) macro defines \(macro) arguments, but the function has \(function)"
        }
    }
}
