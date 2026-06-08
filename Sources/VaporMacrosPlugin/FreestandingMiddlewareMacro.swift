import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxBuilder

public struct FreestandingMiddlewareMacro: DeclarationMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let closureStatements: CodeBlockItemListSyntax
        if let trailing = node.trailingClosure {
            closureStatements = trailing.statements
        } else if let bodyArg = node.arguments.first(where: { $0.label?.text == "body" }),
                  let closure = bodyArg.expression.as(ClosureExprSyntax.self) {
            closureStatements = closure.statements
        } else {
            throw MacroError.missingArguments("Middleware")
        }

        let items = closureStatements.map { Syntax($0.item) }
        return GroupingMacroHelpers.flattenFunctionDecls(from: items, inheriting: nil)
    }
}
