import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxBuilder
import Foundation

public struct ControllerMacro: ExtensionMacro, MemberAttributeMacro, MemberMacro {
    public static func expansion(of node: AttributeSyntax, attachedTo declaration: some DeclGroupSyntax, providingAttributesFor member: some DeclSyntaxProtocol, in context: some MacroExpansionContext) throws -> [AttributeSyntax] {
        []
    }

    public static func expansion(of node: AttributeSyntax, providingMembersOf declaration: some DeclGroupSyntax, conformingTo protocols: [TypeSyntax], in context: some MacroExpansionContext) throws -> [DeclSyntax] {
        []
    }

    public static func expansion(of node: AttributeSyntax, attachedTo declaration: some DeclGroupSyntax, providingExtensionsOf type: some TypeSyntaxProtocol, conformingTo protocols: [TypeSyntax], in context: some MacroExpansionContext) throws -> [ExtensionDeclSyntax] {
        // Find all functions with route macros
        let functions = try declaration.memberBlock.members.compactMap { member -> (String, [String], [String], Bool)? in
            guard let funcDecl = member.decl.as(FunctionDeclSyntax.self) else {
                return nil
            }

            // Look for HTTP method attributes
            for attribute in funcDecl.attributes {
                guard case let .attribute(attr) = attribute,
                      let identifier = attr.attributeName.as(IdentifierTypeSyntax.self),
                      ["GET", "POST", "PUT", "DELETE", "PATCH", "HTTP"].contains(identifier.name.text),
                      case let .argumentList(arguments) = attr.arguments else {
                    continue
                }

                let httpMethod: String
                let customHTTPMethod: Bool
                if identifier.name.text == "HTTP" {
                    // Take the first argument as the HTTP method
                    guard let argument = arguments.first else {
                        throw MacroError.missingArguments("Controller")
                    }
                    httpMethod = argument.expression.description.replacingOccurrences(of: ".", with: "")
                    customHTTPMethod = true
                } else {
                    httpMethod = identifier.name.text
                    customHTTPMethod = false
                }
                let functionName = funcDecl.name.text

                // Parse path components
                var pathComponents: [String] = []
                var parameterTypes: [String] = []

                for (index, arg) in arguments.enumerated() {
                    // If we're a custom HTTP method, discard the first one
                    if customHTTPMethod && index == 0 {
                        continue
                    }
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

                return (httpMethod, pathComponents, parameterTypes, customHTTPMethod)
            }

            return nil
        }

        // Generate the RouteCollection boot function
        var registrationBody = ""

        for (method, pathComponents, _, customHTTPMethod) in functions {
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
                    if customHTTPMethod {
                        return identifier.name.text == "HTTP"
                    } else {
                        return identifier.name.text == method
                    }
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
        \(raw: registrationBody)
        }
        """

        let extensionSyntax: DeclSyntax = """
        extension \(type.trimmed): RouteCollection {
            \(registrationFunc)
        }
        """

        guard let extensionDecl = extensionSyntax.as(ExtensionDeclSyntax.self) else {
            return []
        }

        return [extensionDecl]
    }
}
