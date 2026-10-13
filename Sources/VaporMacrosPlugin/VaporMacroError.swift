enum MacroError: Error, CustomStringConvertible {
    case notAFunction(String)
    case missingArguments(String)
    case missingRequest
    case invalidNumberOfParameters(String, Int, Int)
    case invalidHTTPMethod(String)
    case authParameterNotFound(String)
    case unsupportedMiddlewareGroupContent
    case missingMiddlewareGroupBody(String)
    case middlewareGroupRequiresController

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
        case .invalidHTTPMethod(let method):
            "\(method) is not a valid HTTP Method"
        case .unsupportedMiddlewareGroupContent:
            "Middleware groups can only contain functions and nested middleware groups"
        case .missingMiddlewareGroupBody(let name):
            "#\(name) requires a body containing route handlers"
        case .middlewareGroupRequiresController:
            "Middleware groups must be declared inside a @Controller"
        case .authParameterNotFound(let typeName):
            "No function parameter of type \(typeName) found for @AuthMiddleware"
        }
    }
}
