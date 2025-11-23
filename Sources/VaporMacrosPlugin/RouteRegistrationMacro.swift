import SwiftSyntax
import SwiftSyntaxMacros
import HTTPTypes

public struct RouteRegistrationMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let macroName = node.attributeName.trimmedDescription

        guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
            throw MacroError.notAFunction(macroName)
        }

        let arguments: LabeledExprListSyntax? = switch node.arguments {
        case .argumentList(let arguments): arguments
        default: nil
        }

        let routeHandler = funcDecl.name.trimmedDescription

        // Parse path components and parameter types
        var pathParameters: [String] = []

        guard let arguments, arguments.count >= 2 else {
            throw MacroError.missingArguments("Internal Error")
        }

        var routeBuilder: String? = nil
        var httpMethod: HTTPRequest.Method? = nil

        for (index, argument) in arguments.enumerated() {
            // First is the route builder
            if index == 0 {
                routeBuilder = argument.expression.trimmedDescription
                continue
            }
            
            // Second is the HTTP Method
            if index == 1 {
                let httpMethodStr = argument.expression.trimmedDescription.lowercased()

                guard let parsedHTTPMethod = HTTPRequest.Method(rawValue: httpMethodStr) else {
                    throw MacroError.missingArguments("Internal Error")
                }
                
                httpMethod = parsedHTTPMethod
                continue
            }

            pathParameters.append(argument.expression.trimmedDescription)
        }

        guard let routeBuilder, let httpMethod else {
            throw MacroError.missingArguments("Internal Error")
        }

        let pathParameterValue: String
        if pathParameters.count > 0 {
            pathParameterValue = ", \(pathParameters.joined(separator: ","))"
        } else {
            pathParameterValue = ""
        }

        let routeRegistration: DeclSyntax = """
        let _ = \(raw: routeBuilder).on(.\(raw: httpMethod.rawValue)\(raw: pathParameterValue), use: \(raw: routeHandler))
        """
        return [routeRegistration]
    }
}
