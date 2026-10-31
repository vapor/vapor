import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

enum GroupingMacroHelpers {
    struct MacroCall {
        let macroName: String
        let arguments: LabeledExprListSyntax
        let trailingClosure: ClosureExprSyntax?

        var body: ClosureExprSyntax? {
            trailingClosure ?? arguments.first(where: { $0.label?.text == "body" })?.expression.as(ClosureExprSyntax.self)
        }

        var configurationArguments: LabeledExprListSyntax {
            LabeledExprListSyntax(arguments.filter { $0.label?.text != "body" })
        }

        var isMiddlewareGroup: Bool {
            ["Middleware", "AuthMiddleware"].contains(macroName)
        }
    }

    struct RouteCandidate {
        let function: FunctionDeclSyntax
        let middlewares: [String]
    }

    static func macroCall(_ syntax: Syntax) -> MacroCall? {
        if let decl = syntax.as(MacroExpansionDeclSyntax.self) {
            return MacroCall(macroName: decl.macroName.text, arguments: decl.arguments, trailingClosure: decl.trailingClosure)
        }
        if let expr = syntax.as(MacroExpansionExprSyntax.self) {
            return MacroCall(macroName: expr.macroName.text, arguments: expr.arguments, trailingClosure: expr.trailingClosure)
        }
        return nil
    }

    /// `using:` is a type-checked function from a controller to its middleware.
    /// Swift accepts key-path literals as functions, so the same API supports both.
    /// Evaluation happens in the generated `boot(routes:)`, where an instance exists.
    static func middlewareExpressions(from arguments: LabeledExprListSyntax, skipAuthType: Bool = false) -> [String] {
        let arguments = Array(arguments.filter { $0.label?.text != "body" }.dropFirst(skipAuthType ? 1 : 0))
        let usesController = arguments.first?.label?.text == "using"
        return arguments.map { argument in
            let expression = argument.expression.trimmedDescription
            guard usesController else { return expression }
            if argument.expression.is(KeyPathExprSyntax.self) {
                return "self[keyPath: \(expression)]"
            }
            return "(\(expression))(self)"
        }
    }

    /// Both controller roles use this traversal so lifted handlers and registrations
    /// agree on auth inheritance and middleware order. Middleware accumulates from
    /// outer to inner scopes; the nearest auth declaration selects the injected type.
    static func collectFunctions(
        from items: [Syntax],
        middlewares: [String] = [],
        authType: ExprSyntax? = nil,
        insideGroup: Bool = false
    ) throws -> [RouteCandidate] {
        var results: [RouteCandidate] = []
        for item in items {
            if var function = item.as(FunctionDeclSyntax.self) {
                let localAuth = HTTPMethodMacroUtilities.parseAuthMiddleware(from: function)
                let combinedMiddlewares = middlewares + (localAuth?.middlewares ?? [])
                if localAuth == nil, let authType {
                    let authAttribute = AttributeSyntax(stringLiteral: "@AuthMiddleware(\(authType.trimmedDescription))")
                    function.attributes = AttributeListSyntax([.attribute(authAttribute)] + Array(function.attributes))
                }
                results.append(RouteCandidate(function: function, middlewares: combinedMiddlewares))
                continue
            }
            guard let call = macroCall(item), call.isMiddlewareGroup else {
                if insideGroup { throw MacroError.unsupportedMiddlewareGroupContent }
                continue
            }
            guard let body = call.body else { throw MacroError.missingMiddlewareGroupBody(call.macroName) }
            let isAuth = call.macroName == "AuthMiddleware"
            let inheritedAuth = isAuth ? call.configurationArguments.first?.expression : authType
            let combinedMiddlewares = middlewares + middlewareExpressions(from: call.configurationArguments, skipAuthType: isAuth)
            results.append(
                contentsOf: try collectFunctions(
                    from: body.statements.map { Syntax($0.item) },
                    middlewares: combinedMiddlewares,
                    authType: inheritedAuth,
                    insideGroup: true
                ))
        }
        return results
    }

    static func validateGroupContext(in context: some MacroExpansionContext) throws {
        for lexical in context.lexicalContext {
            if lexical.is(FunctionDeclSyntax.self) { break }
            guard let type = lexical.asProtocol(DeclGroupSyntax.self) else { continue }
            if type.attributes.contains(where: { attribute in
                guard case .attribute(let attribute) = attribute else { return false }
                return attribute.attributeName.as(IdentifierTypeSyntax.self)?.name.text == "Controller"
            }) {
                return
            }
            break
        }
        throw MacroError.middlewareGroupRequiresController
    }
}
