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
        
        // Parse path components and parameter types
        var pathComponents: [String] = []
        var parameterTypes: [String] = []
        
        for arg in arguments {
            let exprStr = arg.expression.description.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if exprStr.hasSuffix(".self") {
                let typeName = exprStr.replacingOccurrences(of: ".self", with: "")
                pathComponents.append(":\(typeName.lowercased())")
                parameterTypes.append(typeName)
            } else {
                let cleaned = exprStr.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                pathComponents.append(cleaned)
            }
        }
        
        let functionName = funcDecl.name.text
        let pathString = pathComponents.joined(separator: "\", \"")
        
        // Generate wrapper that extracts path parameters
        var parameterExtraction = ""
        var callParameters = "req: req"
        
        for (index, paramType) in parameterTypes.enumerated() {
            let paramName = "\(paramType.lowercased())"
            parameterExtraction += """
            let \(paramName) = try req.parameters.require("\(paramType.lowercased())-\(index)", as: \(paramType).self)            
            """
            callParameters += ", \(paramName): \(paramName)"
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
