import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxBuilder
import Foundation
import HTTPTypes

enum HTTPMethodMacroUtilities {
    /// Rendered path segments + dynamic parameter types parsed from a macro attribute's arguments.
    struct ParsedPathComponents {
        /// Each element is either a literal path segment ("users") or a dynamic placeholder (":int0").
        var routeRegistrationSegments: [String]
        /// Names of dynamic parameter types in declaration order (e.g. ["Int", "String"]).
        var parameterTypes: [String]
        /// Next index available for continuing the naming scheme across multiple argument lists.
        var nextIndex: Int
    }

    /// Parse a macro attribute's argument list into path registration segments and dynamic parameter types.
    /// - Parameters:
    ///   - arguments: The attribute's labeled expression list (e.g. `@GET`'s args).
    ///   - startingIndex: Index to use for the first dynamic param encountered; allows continuous indexing
    ///                    when combining a controller prefix with per-route params.
    ///   - skipFirstUnlabeled: Skip the first non-`on:` argument (used for `@HTTP(.patch, ...)` where the
    ///                         first argument is the HTTP method, not a path component).
    static func parsePathComponents(
        from arguments: LabeledExprListSyntax?,
        startingIndex: Int = 0,
        skipFirstUnlabeled: Bool = false
    ) -> ParsedPathComponents {
        var segments: [String] = []
        var types: [String] = []
        var currentIndex = startingIndex
        var skippedFirstUnlabeled = false

        guard let arguments else {
            return ParsedPathComponents(routeRegistrationSegments: [], parameterTypes: [], nextIndex: startingIndex)
        }

        for argument in arguments {
            if argument.label?.text == "on" {
                continue
            }
            if skipFirstUnlabeled && !skippedFirstUnlabeled {
                skippedFirstUnlabeled = true
                continue
            }

            let exprStr = argument.expression.description.trimmingCharacters(in: .whitespacesAndNewlines)
            if exprStr.hasSuffix(".self") {
                let typeName = exprStr.replacingOccurrences(of: ".self", with: "")
                segments.append(":\(typeName.lowercased())\(currentIndex)")
                types.append(typeName)
                currentIndex += 1
            } else {
                let cleaned = exprStr.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                segments.append(cleaned)
            }
        }

        return ParsedPathComponents(routeRegistrationSegments: segments, parameterTypes: types, nextIndex: currentIndex)
    }

    /// If the macro is expanded inside a `@Controller`-annotated type declaration, return its attribute arguments.
    /// Returns nil when not inside a controller or when the enclosing type is not `@Controller`-annotated.
    static func enclosingControllerArguments(in context: some MacroExpansionContext) -> LabeledExprListSyntax? {
        for lexical in context.lexicalContext {
            let attributes: AttributeListSyntax? = {
                if let structDecl = lexical.as(StructDeclSyntax.self) { return structDecl.attributes }
                if let classDecl = lexical.as(ClassDeclSyntax.self) { return classDecl.attributes }
                if let actorDecl = lexical.as(ActorDeclSyntax.self) { return actorDecl.attributes }
                return nil
            }()

            guard let attributes else { continue }

            for attribute in attributes {
                guard case let .attribute(attr) = attribute,
                      let identifier = attr.attributeName.as(IdentifierTypeSyntax.self),
                      identifier.name.text == "Controller" else {
                    continue
                }
                switch attr.arguments {
                case .argumentList(let args):
                    return args
                default:
                    // @Controller with no arguments.
                    return LabeledExprListSyntax([])
                }
            }
        }
        return nil
    }

    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext,
        for method: HTTPRequest.Method,
        customHTTPMethod: Bool = false
    ) throws -> [DeclSyntax] {
        let macroName = node.attributeName.trimmedDescription

        guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
            throw MacroError.notAFunction(macroName)
        }

        let arguments: LabeledExprListSyntax? = switch node.arguments {
        case .argumentList(let arguments): arguments
        default: nil
        }

        var funcParameters: [FunctionParameterSyntax] = []

        // Make sure it isn't empty
        guard !funcDecl.signature.parameterClause.parameters.isEmpty else {
            throw MacroError.missingRequest
        }

        // Get all the parameters for the function we're wrapping
        for (index, parameter) in funcDecl.signature.parameterClause.parameters.enumerated() {
            // Make sure the first is the request followed by Request
            if index == 0 {
                guard parameter.type.description == "Request" else {
                    throw MacroError.missingRequest
                }
            } else {
                funcParameters.append(parameter)
            }
        }

        // Detect @AuthMiddleware attribute on the function
        let authInfo = parseAuthMiddleware(from: funcDecl)

        // Separate auth params from path params
        var pathParams: [FunctionParameterSyntax] = []
        var allParamsWithAuth: [(param: FunctionParameterSyntax, isAuth: Bool, isOptionalAuth: Bool)] = []

        for param in funcParameters {
            if let authInfo {
                let paramType = param.type.trimmedDescription
                // Match both `User` and `User?` / `Optional<User>` against the auth type
                let strippedType = paramType.hasSuffix("?")
                    ? String(paramType.dropLast())
                    : paramType.hasPrefix("Optional<") && paramType.hasSuffix(">")
                        ? String(paramType.dropFirst("Optional<".count).dropLast())
                        : paramType
                if strippedType == authInfo.type {
                    let isOptional = paramType != strippedType
                    allParamsWithAuth.append((param: param, isAuth: true, isOptionalAuth: isOptional))
                } else {
                    allParamsWithAuth.append((param: param, isAuth: false, isOptionalAuth: false))
                    pathParams.append(param)
                }
            } else {
                allParamsWithAuth.append((param: param, isAuth: false, isOptionalAuth: false))
                pathParams.append(param)
            }
        }

        if let authInfo {
            guard allParamsWithAuth.contains(where: { $0.isAuth }) else {
                throw MacroError.authParameterNotFound(authInfo.type)
            }
        }

        // Detect enclosing @Controller so we can account for prefix-declared dynamic params.
        // Prefix params come first in the handler's parameter list by convention.
        let enclosingPrefix = enclosingControllerArguments(in: context).map {
            parsePathComponents(from: $0, startingIndex: 0, skipFirstUnlabeled: false)
        } ?? ParsedPathComponents(routeRegistrationSegments: [], parameterTypes: [], nextIndex: 0)

        // Parse this macro's own path components, indexed continuously after the prefix's dynamic params.
        let routeComponents = parsePathComponents(
            from: arguments,
            startingIndex: enclosingPrefix.nextIndex,
            skipFirstUnlabeled: customHTTPMethod
        )

        let allParameterTypes = enclosingPrefix.parameterTypes + routeComponents.parameterTypes

        // Detect `on:` label for standalone/freestanding usage (not used when inside a controller).
        var routeRegistrationVariable: String? = nil
        if let arguments {
            for argument in arguments where argument.label?.text == "on" {
                routeRegistrationVariable = argument.expression.description.trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }

        guard pathParams.count == allParameterTypes.count else {
            throw MacroError.invalidNumberOfParameters(macroName, allParameterTypes.count, pathParams.count)
        }

        let functionName = funcDecl.name.text

        // Generate wrapper that extracts path parameters and auth
        var parameterExtraction = ""
        var callParameters = "req: req"
        var pathParamIndex = 0
        let dynamicIndexBase = 0  // index used in :typeN naming starts at 0 regardless of prefix vs route

        for (param, isAuth, isOptionalAuth) in allParamsWithAuth {
            let functionParameterName = param.firstName.text
            if isAuth, let authInfo {
                let varName = param.secondName?.text ?? param.firstName.text
                if isOptionalAuth {
                    parameterExtraction += """
                    let \(varName) = req.auth.get(\(authInfo.type).self)

                    """
                } else {
                    parameterExtraction += """
                    let \(varName) = try req.auth.require(\(authInfo.type).self)

                    """
                }
                callParameters += ", \(functionParameterName): \(varName)"
            } else {
                let paramType = allParameterTypes[pathParamIndex]
                let globalIndex = dynamicIndexBase + pathParamIndex
                let parameterName = "\(paramType.lowercased())\(globalIndex)"
                parameterExtraction += """
                let \(parameterName) = try req.parameters.require("\(paramType.lowercased())\(globalIndex)", as: \(paramType).self)

                """
                callParameters += ", \(functionParameterName): \(parameterName)"
                pathParamIndex += 1
            }
        }

        let isAsyncFunction = funcDecl.signature.effectSpecifiers?.asyncSpecifier != nil

        // If no explicit `on:` was provided, check lexical context for an enclosing function
        // with an Application or RoutesBuilder parameter and auto-register
        if routeRegistrationVariable == nil {
            for lexicalSyntax in context.lexicalContext {
                guard let enclosingFunc = lexicalSyntax.as(FunctionDeclSyntax.self) else {
                    continue
                }
                for param in enclosingFunc.signature.parameterClause.parameters {
                    let typeName = param.type.trimmedDescription
                    if typeName.contains("Application") || typeName.contains("RoutesBuilder") {
                        routeRegistrationVariable = param.secondName?.text ?? param.firstName.text
                        break
                    }
                }
                if routeRegistrationVariable != nil { break }
            }
        }

        // Check if we're inside a type declaration (Controller context) vs a function (standalone)
        let isInsideType = context.lexicalContext.contains { lexical in
            lexical.is(StructDeclSyntax.self) || lexical.is(ClassDeclSyntax.self) || lexical.is(EnumDeclSyntax.self)
        }

        if isInsideType {
            // Inside a Controller: generate a separate wrapper function as a member
            let wrapperFunc: DeclSyntax = """
            @Sendable func _route_\(raw: functionName)(req: Request) async throws -> Response {
                \(raw: parameterExtraction)let result: some ResponseEncodable = try \(raw: isAsyncFunction ? "await " : "")\(raw: functionName)(\(raw: callParameters))
                return try await result.encodeResponse(for: req)
            }
            """
            return [wrapperFunc]
        }

        if let routeRegistrationVariable {
            let path = routeComponents.routeRegistrationSegments.joined(separator: "\", \"")
            let pathRegistration = if path == "" {
                ""
            } else {
                ", \"\(path)\""
            }
            // Standalone context: inline the handler into the on() call as a single declaration
            // to avoid peer declarations referencing each other (which Swift doesn't support)
            let routeRegistration: DeclSyntax = """
            let _register_\(raw: functionName) = \(raw: routeRegistrationVariable).on(.\(raw: method.rawValue.lowercased())\(raw: pathRegistration)) { req -> Response in
                \(raw: parameterExtraction)let result: some ResponseEncodable = try \(raw: isAsyncFunction ? "await " : "")\(raw: functionName)(\(raw: callParameters))
                return try await result.encodeResponse(for: req)
            }
            """
            return [routeRegistration]
        }

        // No route registration variable found - generate just the wrapper function
        let wrapperFunc: DeclSyntax = """
        @Sendable func _route_\(raw: functionName)(req: Request) async throws -> Response {
            \(raw: parameterExtraction)let result: some ResponseEncodable = try \(raw: isAsyncFunction ? "await " : "")\(raw: functionName)(\(raw: callParameters))
            return try await result.encodeResponse(for: req)
        }
        """
        return [wrapperFunc]
    }

    /// Parse all `@Middleware(...)` attributes on a function in source order, concatenating
    /// their arguments. Stacking multiple `@Middleware` attributes is supported.
    static func parseMiddleware(from funcDecl: FunctionDeclSyntax) -> [String] {
        parseMiddlewareAttributes(from: funcDecl.attributes)
    }

    /// Parse all `@Middleware(...)` attributes on a type declaration (struct/class/actor), concatenating
    /// their arguments. Stacking multiple `@Middleware` attributes is supported.
    static func parseMiddleware(from declGroup: some DeclGroupSyntax) -> [String] {
        parseMiddlewareAttributes(from: declGroup.attributes)
    }

    private static func parseMiddlewareAttributes(from attributes: AttributeListSyntax) -> [String] {
        var result: [String] = []
        for attribute in attributes {
            guard case let .attribute(attr) = attribute,
                  let identifier = attr.attributeName.as(IdentifierTypeSyntax.self),
                  identifier.name.text == "Middleware",
                  let args = attr.arguments?.as(LabeledExprListSyntax.self) else {
                continue
            }
            for arg in args {
                let exprStr = arg.expression.description.trimmingCharacters(in: .whitespacesAndNewlines)
                if !exprStr.isEmpty {
                    result.append(exprStr)
                }
            }
        }
        return result
    }

    /// Parse @AuthMiddleware attribute from a function declaration
    static func parseAuthMiddleware(from funcDecl: FunctionDeclSyntax) -> (type: String, middlewares: [String])? {
        for attribute in funcDecl.attributes {
            guard case let .attribute(attr) = attribute,
                  let identifier = attr.attributeName.as(IdentifierTypeSyntax.self),
                  identifier.name.text == "AuthMiddleware",
                  let args = attr.arguments?.as(LabeledExprListSyntax.self) else {
                continue
            }
            var authType: String? = nil
            var middlewares: [String] = []
            for (i, arg) in args.enumerated() {
                let exprStr = arg.expression.description.trimmingCharacters(in: .whitespacesAndNewlines)
                if i == 0 {
                    authType = exprStr.replacingOccurrences(of: ".self", with: "")
                } else {
                    middlewares.append(exprStr)
                }
            }
            if let authType {
                return (type: authType, middlewares: middlewares)
            }
        }
        return nil
    }
}
