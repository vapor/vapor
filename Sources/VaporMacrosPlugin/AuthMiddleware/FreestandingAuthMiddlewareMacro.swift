import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxBuilder
import Foundation

public struct FreestandingAuthMiddlewareMacro: DeclarationMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard node.arguments.first != nil else {
            throw MacroError.missingArguments("AuthMiddleware")
        }

        let closureStatements: CodeBlockItemListSyntax
        if let trailing = node.trailingClosure {
            closureStatements = trailing.statements
        } else if let bodyArg = node.arguments.first(where: { $0.label?.text == "body" }),
                  let closure = bodyArg.expression.as(ClosureExprSyntax.self) {
            closureStatements = closure.statements
        } else {
            throw MacroError.missingArguments("AuthMiddleware")
        }

        let argsText = node.arguments
            .filter { $0.label?.text != "body" }
            .map { $0.expression.description.trimmingCharacters(in: .whitespacesAndNewlines) }
            .joined(separator: ", ")
        let authAttr = AttributeSyntax(stringLiteral: "@AuthMiddleware(\(argsText))")

        let items = closureStatements.map { Syntax($0.item) }
        return GroupingMacroHelpers.flattenFunctionDecls(from: items, inheriting: authAttr)
    }
}
