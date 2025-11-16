import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxBuilder
import Foundation

public struct HTTPGetMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
            throw MacroError.notAFunction
        }
        
        guard case let .argumentList(arguments) = node.arguments else {
            throw MacroError.missingArguments
        }

        var funcParameters: [FunctionParameterSyntax] = []

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

        for arg in arguments {
            let exprStr = arg.expression.description.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if exprStr.hasSuffix(".self") {
                let typeName = exprStr.replacingOccurrences(of: ".self", with: "")
                parameterTypes.append(typeName)
            }
        }

        guard funcParameters.count == parameterTypes.count else {
            throw MacroError.missingArguments
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
        
        let wrapperFunc: DeclSyntax = """
        func _route_\(raw: functionName)(req: Request) async throws -> Response {
        \(raw: parameterExtraction.isEmpty ? "" : "    \(parameterExtraction)")    let result = try await \(raw: functionName)(\(raw: callParameters))
            return try await result.encodeResponse(for: req)
        }
        """
        
        return [wrapperFunc]
    }
}
