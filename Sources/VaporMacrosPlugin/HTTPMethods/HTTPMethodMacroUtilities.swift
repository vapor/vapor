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

        // Parse path components and parameter types
        var parameterTypes: [String] = []
        var routeRegistrationVariable: String? = nil

        if let arguments {
            for (index, argument) in arguments.enumerated() {
                if argument.label?.text == "on" {
                    routeRegistrationVariable = argument.expression.description.trimmingCharacters(in: .whitespacesAndNewlines)
                    continue
                }
                // If this is a custom HTTP method we need to ignore the first argument, as that's the custom HTTP method
                if customHTTPMethod && index == 0 {
                    continue
                }

                let exprStr = argument.expression.description.trimmingCharacters(in: .whitespacesAndNewlines)

                if exprStr.hasSuffix(".self") {
                    let typeName = exprStr.replacing(".self", with: "")
                    parameterTypes.append(typeName)
                }
            }
        }

        guard funcParameters.count == parameterTypes.count else {
            throw MacroError.invalidNumberOfParameters(macroName, parameterTypes.count, funcParameters.count)
        }

        let functionName = funcDecl.name.text

        // Generate wrapper that extracts path parameters
        var parameterExtraction = ""
        var callParameters = "req: req"

        for (index, paramType) in parameterTypes.enumerated() {
            let functionParameterName = funcParameters[index].firstName.text
            let parameterName = "\(paramType.lowercased())\(index)"
            parameterExtraction += """
            let \(parameterName) = try req.parameters.require("\(paramType.lowercased())\(index)", as: \(paramType).self)
            
            """
            callParameters += ", \(functionParameterName): \(parameterName)"
        }

        let isAsyncFunction = funcDecl.signature.effectSpecifiers?.asyncSpecifier != nil

        let wrapperFunc: DeclSyntax = """
        @Sendable func _route_\(raw: functionName)(req: Request) async throws -> Response {
            \(raw: parameterExtraction)let result: some ResponseEncodable = try \(raw: isAsyncFunction ? "await " : "")\(raw: functionName)(\(raw: callParameters))
            return try await result.encodeResponse(for: req)
        }
        """

        if let routeRegistrationVariable {
            var currentDynamicPathParameterIndex = 0
            var pathComponents: [String] = []
            if let arguments {
                for (index, arg) in arguments.enumerated() {
                    // Discard the first one (the place to register the routes) and if we're a custom HTTP method, discard the next one
                    if index == 0 || customHTTPMethod && index == 1 {
                        continue
                    }
                    let exprStr = arg.expression.description.trimmingCharacters(in: .whitespacesAndNewlines)

                    // Check if it's a type (contains .self)
                    if exprStr.hasSuffix(".self") {
                        let typeName = exprStr.replacing(".self", with: "")
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
            let routeRegistration: DeclSyntax = """
            @RouteRegistration(routeBuilder: \(raw: routeRegistrationVariable), method: \(raw: method.rawValue)\(raw: pathRegistration)
            @Sendable func _route_\(raw: functionName)(req: Request) async throws -> Response {
                \(raw: parameterExtraction)let result: some ResponseEncodable = try \(raw: isAsyncFunction ? "await " : "")\(raw: functionName)(\(raw: callParameters))
                return try await result.encodeResponse(for: req)
            }
            """
            return [routeRegistration]
        }

        return [wrapperFunc]
    }
}
