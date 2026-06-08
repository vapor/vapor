import SwiftSyntax
import SwiftSyntaxBuilder
import Foundation

enum GroupingMacroHelpers {
    struct MacroCall {
        let macroName: String
        let arguments: LabeledExprListSyntax
        let trailingClosure: ClosureExprSyntax?
    }

    /// Unwraps a freestanding macro call from either a decl or expr position
    static func macroCall(_ syntax: Syntax) -> MacroCall? {
        if let decl = syntax.as(MacroExpansionDeclSyntax.self) {
            return MacroCall(
                macroName: decl.macroName.text,
                arguments: decl.arguments,
                trailingClosure: decl.trailingClosure
            )
        }
        if let expr = syntax.as(MacroExpansionExprSyntax.self) {
            return MacroCall(
                macroName: expr.macroName.text,
                arguments: expr.arguments,
                trailingClosure: expr.trailingClosure
            )
        }
        return nil
    }

    /// Recursively flatten function declarations from a grouping macro's
    /// trailing closure so the freestanding expansion can re-emit them at the
    /// enclosing type's member scope (letting `@GET`/`@POST`/... peer macros
    /// expand). Nested `#AuthMiddleware(...)` groupings prepend their auth
    /// attribute to the lifted functions; nested `#Middleware(...)` groupings
    /// recurse without adding attributes since their middleware is read by
    /// `@Controller` from the original syntax tree
    static func flattenFunctionDecls(
        from items: [Syntax],
        inheriting authAttr: AttributeSyntax?
    ) -> [DeclSyntax] {
        var results: [DeclSyntax] = []
        for item in items {
            if let funcDecl = item.as(FunctionDeclSyntax.self) {
                if let authAttr {
                    var newAttrs = AttributeListSyntax([.attribute(authAttr)])
                    for a in funcDecl.attributes { newAttrs.append(a) }
                    results.append(DeclSyntax(funcDecl.with(\.attributes, newAttrs)))
                } else {
                    results.append(DeclSyntax(funcDecl))
                }
                continue
            }
            guard let call = macroCall(item), let trailing = call.trailingClosure else {
                continue
            }
            let innerItems = trailing.statements.map { Syntax($0.item) }
            switch call.macroName {
            case "Middleware":
                results.append(contentsOf: flattenFunctionDecls(from: innerItems, inheriting: authAttr))
            case "AuthMiddleware":
                let argsText = call.arguments.map {
                    $0.expression.description.trimmingCharacters(in: .whitespacesAndNewlines)
                }.joined(separator: ", ")
                let newAuthAttr = AttributeSyntax(stringLiteral: "@AuthMiddleware(\(argsText))")
                results.append(contentsOf: flattenFunctionDecls(from: innerItems, inheriting: newAuthAttr))
            default:
                continue
            }
        }
        return results
    }
}
