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
            // Make sure the first is the request
            if index == 0 {
                guard parameter.type.description == "Request" else {
                    throw MacroError.missingRequest
                }
            } else {
                // Otherwise store them for later
                funcParameters.append(parameter)
            }
        }

        // Detect @AuthMiddleware attribute on the function
        let authInfo = parseAuthMiddleware(from: funcDecl)

        // Separate auth params from path params
        var pathParams: [FunctionParameterSyntax] = []
        var allParamsWithAuth: [(param: FunctionParameterSyntax, isAuth: Bool)] = []

        for param in funcParameters {
            if let authInfo, param.type.trimmedDescription == authInfo.type {
                allParamsWithAuth.append((param: param, isAuth: true))
            } else {
                allParamsWithAuth.append((param: param, isAuth: false))
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

        if let arguments {
            for (index, argument) in arguments.enumerated() {
                // If this is a custom HTTP method we need to ignore the first argument, as that's the custom HTTP method
                if customHTTPMethod && index == 0 {
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

        for (param, isAuth) in allParamsWithAuth {
            let functionParameterName = param.firstName.text
            if isAuth, let authInfo {
                let varName = param.secondName?.text ?? param.firstName.text
                parameterExtraction += """
                let \(varName) = try req.auth.require(\(authInfo.type).self)

                """
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

        let wrapperFunc: DeclSyntax = """
        func _route_\(raw: functionName)(req: Request) async throws -> Response {
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
