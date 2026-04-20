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
        // Flatten direct members with function decls, plus any inner functions
        // wrapped in a `#AuthMiddleware(...)` freestanding call
        var candidateFunctions: [FunctionDeclSyntax] = []
        var debugSeen: [String] = []
        for member in declaration.memberBlock.members {
            debugSeen.append(member.decl.kind.syntaxNodeType == MacroExpansionDeclSyntax.self ? "macroexp" : (member.decl.is(FunctionDeclSyntax.self) ? "func" : String(describing: member.decl.kind)))
            if let funcDecl = member.decl.as(FunctionDeclSyntax.self) {
                candidateFunctions.append(funcDecl)
            } else if let macroCall = member.decl.as(MacroExpansionDeclSyntax.self),
                      macroCall.macroName.text == "AuthMiddleware",
                      let trailing = macroCall.trailingClosure {
                let args = macroCall.arguments
                let authAttrArgs = args.map {
                    $0.expression.description.trimmingCharacters(in: .whitespacesAndNewlines)
                }.joined(separator: ", ")
                let authAttr = AttributeSyntax(stringLiteral: "@AuthMiddleware(\(authAttrArgs))")
                for stmt in trailing.statements {
                    guard let innerFunc = stmt.item.as(FunctionDeclSyntax.self) else { continue }
                    var newAttrs = AttributeListSyntax()
                    newAttrs.append(.attribute(authAttr))
                    for a in innerFunc.attributes { newAttrs.append(a) }
                    candidateFunctions.append(innerFunc.with(\.attributes, newAttrs))
                }
            }
        }

        // Find all functions with route macros
        let functions = try candidateFunctions.compactMap { funcDecl -> (FunctionDeclSyntax, String, [String], [String])? in

            // Look for HTTP method attributes
            for attribute in funcDecl.attributes {
                guard case let .attribute(attr) = attribute,
                      let identifier = attr.attributeName.as(IdentifierTypeSyntax.self),
                      ["GET", "POST", "PUT", "DELETE", "PATCH", "HTTP"].contains(identifier.name.text) else {
                    continue
                }

                let arguments: LabeledExprListSyntax? = switch attr.arguments {
                case .argumentList(let arguments): arguments
                default: nil
                }
                let httpMethod: String
                let customHTTPMethod: Bool
                if identifier.name.text == "HTTP" {
                    // Take the first argument as the HTTP method
                    guard let argument = arguments?.first else {
                        throw MacroError.missingArguments("Controller")
                    }
                    httpMethod = argument.expression.description.replacingOccurrences(of: ".", with: "")
                    customHTTPMethod = true
                } else {
                    httpMethod = identifier.name.text
                    customHTTPMethod = false
                }

                // Parse path components
                var pathComponents: [String] = []
                var currentDynamicPathParameterIndex = 0
                if let arguments {
                    for (index, arg) in arguments.enumerated() {
                        // If we're a custom HTTP method, discard the first one
                        if customHTTPMethod && index == 0 {
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

                // Check for @AuthMiddleware
                let middlewareExprs: [String] = {
                    guard let authInfo = HTTPMethodMacroUtilities.parseAuthMiddleware(from: funcDecl) else {
                        return []
                    }
                    return authInfo.middlewares
                }()

                return (funcDecl, httpMethod, pathComponents, middlewareExprs)
            }

            return nil
        }

        // Generate the RouteCollection boot function
        var registrationBody = ""

        for (functionDeclaration, method, pathComponents, middlewares) in functions {
            let path = pathComponents.joined(separator: "\", \"")
            let methodLower = method.lowercased()

            // Call the function generated by the HTTP Method Macros
            let functionName = "_route_\(functionDeclaration.name.text)"
            let pathRegistration = if path == "" {
                ""
            } else {
                "(\"\(path)\")"
            }

            if middlewares.isEmpty {
                registrationBody += """
                routes.\(methodLower)\(pathRegistration) { req async throws -> Response in
                    try await self.\(functionName)(req: req)
                }

                """
            } else {
                let middlewareList = middlewares.joined(separator: ", ")
                registrationBody += """
                routes.grouped(\(middlewareList)).\(methodLower)\(pathRegistration) { req async throws -> Response in
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
