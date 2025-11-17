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
              let firstArg = arguments.first else {
            throw MacroError.missingArguments("Method")
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

