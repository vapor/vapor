enum MacroError: Error, CustomStringConvertible {
    case notAFunction
    case missingArguments
    
    var description: String {
        switch self {
        case .notAFunction:
            return "@GET can only be applied to functions"
        case .missingArguments:
            return "@GET requires path components as arguments"
        }
    }
}