import SwiftSyntaxMacros
import SwiftSyntax
import HTTPTypes

public struct HTTPMethodMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Get the first parameter for the macro
        guard let arguments = node.arguments?.as(LabeledExprListSyntax.self),
              var firstArg = arguments.first else {
            throw MacroError.missingArguments("Method")
        }

        if firstArg.label?.description == "on" {
            // We're not in a controller and have a routes builder passed in, so get the next argument
            guard let nextArgument = arguments.dropFirst().first else {
                throw MacroError.missingArguments("Method")
            }
            firstArg = nextArgument
        }

        let methodExpr = firstArg.expression

        // Check if it's a member access (like .get, .post)
        let httpMethod: HTTPRequest.Method
        if let memberAccess = methodExpr.as(MemberAccessExprSyntax.self) {
            let methodName = memberAccess.declName.baseName.text
            guard let httpMethodFound = HTTPRequest.Method(methodName) else {
                throw MacroError.invalidHTTPMethod(methodName)
            }
            httpMethod = httpMethodFound
        } else {
            throw MacroError.invalidHTTPMethod(methodExpr.description)
        }

        return try HTTPMethodMacroUtilities.expansion(of: node, providingPeersOf: declaration, in: context, for: httpMethod, customHTTPMethod: true)
    }
}

