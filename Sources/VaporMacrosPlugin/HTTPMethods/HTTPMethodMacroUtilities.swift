import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxBuilder
import Foundation
import HTTPTypes

enum HTTPMethodMacroUtilities {
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

        // Parse path components and parameter types
        var parameterTypes: [String] = []
        var routeRegistrationVariable: String? = nil

        var skippedHTTPMethod = false
        if let arguments {
            for (_, argument) in arguments.enumerated() {
                if argument.label?.text == "on" {
                    routeRegistrationVariable = argument.expression.description.trimmingCharacters(in: .whitespacesAndNewlines)
                    continue
                }
                // Skip the first non-on: argument for custom HTTP methods (that's the HTTP method itself)
                if customHTTPMethod && !skippedHTTPMethod {
                    skippedHTTPMethod = true
                    continue
                }

                let exprStr = argument.expression.description.trimmingCharacters(in: .whitespacesAndNewlines)

                if exprStr.hasSuffix(".self") {
                    let typeName = exprStr.replacingOccurrences(of: ".self", with: "")
                    parameterTypes.append(typeName)
                }
            }
        }

        guard pathParams.count == parameterTypes.count else {
            throw MacroError.invalidNumberOfParameters(macroName, parameterTypes.count, pathParams.count)
        }

        let functionName = funcDecl.name.text

        // Generate wrapper that extracts path parameters and auth
        var parameterExtraction = ""
        var callParameters = "req: req"
        var pathParamIndex = 0

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
                let paramType = parameterTypes[pathParamIndex]
                let parameterName = "\(paramType.lowercased())\(pathParamIndex)"
                parameterExtraction += """
                let \(parameterName) = try req.parameters.require("\(paramType.lowercased())\(pathParamIndex)", as: \(paramType).self)

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
            var currentDynamicPathParameterIndex = 0
            var pathComponents: [String] = []
            if let arguments {
                var skippedHTTPMethodInPath = false
                for (_, arg) in arguments.enumerated() {
                    // Skip the `on:` argument
                    if arg.label?.text == "on" {
                        continue
                    }
                    // Skip the first non-on: argument for custom HTTP methods
                    if customHTTPMethod && !skippedHTTPMethodInPath {
                        skippedHTTPMethodInPath = true
                        continue
                    }
                    let exprStr = arg.expression.description.trimmingCharacters(in: .whitespacesAndNewlines)

                    // Check if it's a type (contains .self)
                    if exprStr.hasSuffix(".self") {
                        let typeName = exprStr.replacingOccurrences(of: ".self", with: "")
                        pathComponents.append(":\(typeName.lowercased())\(currentDynamicPathParameterIndex)")
                        currentDynamicPathParameterIndex += 1
                    } else {
                        // It's a string literal
                        let cleaned = exprStr.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                        pathComponents.append(cleaned)
                    }
                }
            }

            let path = pathComponents.joined(separator: "\", \"")
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
