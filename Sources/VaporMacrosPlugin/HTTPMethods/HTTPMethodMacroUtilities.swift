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
                // Otherwise store them for late
                funcParameters.append(parameter)
            }
        }

        // Parse path components and parameter types
        var parameterTypes: [String] = []
        var pathComponents: [String] = []
        var currentDynamicPathParameterIndex = 0

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
                    pathComponents.append(":\(typeName.lowercased())\(currentDynamicPathParameterIndex)")
                    currentDynamicPathParameterIndex += 1
                } else {
                    let cleaned = exprStr.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                    pathComponents.append(cleaned)
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

        // Check if we're inside a type declaration
        let isInsideType = context.lexicalContext.contains { syntax in
            syntax.is(StructDeclSyntax.self) ||
            syntax.is(ClassDeclSyntax.self) ||
            syntax.is(EnumDeclSyntax.self) ||
            syntax.is(ActorDeclSyntax.self)
        }

        if isInsideType {
            // Inside a type, generate _route_X for use by @Controller
            let wrapperFunc: DeclSyntax = """
            func _route_\(raw: functionName)(req: Request) async throws -> Response {
                \(raw: parameterExtraction)let result: some ResponseEncodable = try \(raw: isAsyncFunction ? "await " : "")\(raw: functionName)(\(raw: callParameters))
                return try await result.encodeResponse(for: req)
            }
            """
            return [wrapperFunc]
        }

        let methodLower = method.rawValue.lowercased()
        let pathArgs = pathComponents.map { "\"\($0)\"" }.joined(separator: ", ")
        let onArgs = pathArgs.isEmpty ? ".\(methodLower)" : ".\(methodLower), \(pathArgs)"

        // Check if we're inside a function with a RoutesBuilder/Application parameter
        let routesParamName: String? = {
            for lexicalSyntax in context.lexicalContext {
                guard let enclosingFunc = lexicalSyntax.as(FunctionDeclSyntax.self) else {
                    continue
                }
                for param in enclosingFunc.signature.parameterClause.parameters {
                    let typeName = param.type.trimmedDescription
                    if typeName.contains("Application") || typeName.contains("RoutesBuilder") {
                        return param.secondName?.text ?? param.firstName.text
                    }
                }
            }
            return nil
        }()

        guard let routesParamName else {
            return []
        }

        // Inside a function with a routes param — auto-register
        let autoRegister: DeclSyntax = """
        let _route_\(raw: functionName): Void = {
            \(raw: routesParamName).on(\(raw: onArgs)) { req async throws -> Response in
                \(raw: parameterExtraction)let result: some ResponseEncodable = try \(raw: isAsyncFunction ? "await " : "")\(raw: functionName)(\(raw: callParameters))
                return try await result.encodeResponse(for: req)
            }
        }()
        """
        return [autoRegister]
    }
}
