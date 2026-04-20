import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxBuilder
import Foundation

public struct FreestandingAuthMiddlewareMacro: DeclarationMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let arguments = node.arguments
        guard let authArg = arguments.first else {
            throw MacroError.missingArguments("AuthMiddleware")
        }

        var middlewareExprs: [String] = []
        for (index, argument) in arguments.enumerated() where index > 0 {
            if argument.label?.text == "body" { continue }
            middlewareExprs.append(
                argument.expression.description.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }

        let authTypeExpr = authArg.expression.description.trimmingCharacters(in: .whitespacesAndNewlines)

        let closureStatements: CodeBlockItemListSyntax
        if let trailing = node.trailingClosure {
            closureStatements = trailing.statements
        } else if let bodyArg = arguments.first(where: { $0.label?.text == "body" }),
                  let closure = bodyArg.expression.as(ClosureExprSyntax.self) {
            closureStatements = closure.statements
        } else {
            throw MacroError.missingArguments("AuthMiddleware")
        }

        let authAttributeArguments = ([authTypeExpr] + middlewareExprs).joined(separator: ", ")

        var results: [DeclSyntax] = []
        for statement in closureStatements {
            guard let funcDecl = statement.item.as(FunctionDeclSyntax.self) else {
                continue
            }

            let funcSource = funcDecl.trimmedDescription
            let decoratedSource = "@AuthMiddleware(\(authAttributeArguments))\n\(funcSource)"
            results.append(DeclSyntax(stringLiteral: decoratedSource))
        }

        return results
    }
}
