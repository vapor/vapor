import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxBuilder
import Foundation

public struct ControllerMacro: MemberAttributeMacro, MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AttributeSyntax] {
        // This adds the peer macros to each function, if needed
        return []
    }
    
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Find all functions with route macros
        let functions = declaration.memberBlock.members.compactMap { member -> (String, [String], [String])? in
            guard let funcDecl = member.decl.as(FunctionDeclSyntax.self) else {
                return nil
            }
            
            // Look for HTTP method attributes
            for attribute in funcDecl.attributes {
                guard case let .attribute(attr) = attribute,
                      let identifier = attr.attributeName.as(IdentifierTypeSyntax.self),
                      ["GET", "POST", "PUT", "DELETE", "PATCH"].contains(identifier.name.text),
                      case let .argumentList(arguments) = attr.arguments else {
                    continue
                }
                
                let httpMethod = identifier.name.text
                let functionName = funcDecl.name.text
                
                // Parse path components
                var pathComponents: [String] = []
                var parameterTypes: [String] = []
                
                for arg in arguments {
                    let exprStr = arg.expression.description.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // Check if it's a type (contains .self)
                    if exprStr.hasSuffix(".self") {
                        let typeName = exprStr.replacingOccurrences(of: ".self", with: "")
                        pathComponents.append(":\(typeName.lowercased())")
                        parameterTypes.append(typeName)
                    } else {
                        // It's a string literal
                        let cleaned = exprStr.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                        pathComponents.append(cleaned)
                    }
                }
                
                return (httpMethod, pathComponents, parameterTypes)
            }
            
            return nil
        }
        
        // Generate the registration function
        var registrationBody = ""
        
        for (method, pathComponents, _) in functions {
            let path = pathComponents.joined(separator: "\", \"")
            let methodLower = method.lowercased()
            
            // Find the function name from the original declaration
            if let funcDecl = declaration.memberBlock.members.compactMap({ 
                $0.decl.as(FunctionDeclSyntax.self) 
            }).first(where: { funcDecl in
                funcDecl.attributes.contains { attr in
                    guard case let .attribute(attrNode) = attr,
                          let identifier = attrNode.attributeName.as(IdentifierTypeSyntax.self) else {
                        return false
                    }
                    return identifier.name.text == method
                }
            }) {
                let functionName = funcDecl.name.text
                registrationBody += """
                    routes.\(methodLower)("\(path)") { req async throws in
                        try await self.\(functionName)(req: req)
                    }
                    
                """
            }
        }
        
        let registrationFunc: DeclSyntax = """
        func boot(routes: any RoutesBuilder) throws {
        \(raw: registrationBody.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        """
        
        return [registrationFunc]
    }
}
