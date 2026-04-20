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
        // Parse the @Controller(...) path prefix. Supports string literals and `Type.self` for dynamic params.
        let controllerArgs: LabeledExprListSyntax? = switch node.arguments {
        case .argumentList(let args): args
        default: nil
        }
        let prefix = HTTPMethodMacroUtilities.parsePathComponents(from: controllerArgs, startingIndex: 0)

        // Type-level @Middleware applied to all routes. Goes outside the path group so middleware
        // sees every request reaching the controller, not just path-matched ones.
        let typeMiddlewares = HTTPMethodMacroUtilities.parseMiddleware(from: declaration)

        // Find all functions with route macros
        let functions = try declaration.memberBlock.members.compactMap { member -> (FunctionDeclSyntax, String, [String], [String], [String])? in
            guard let funcDecl = member.decl.as(FunctionDeclSyntax.self) else {
                return nil
            }

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

                // Parse the route-local path components, indexed continuously after the prefix.
                let route = HTTPMethodMacroUtilities.parsePathComponents(
                    from: arguments,
                    startingIndex: prefix.nextIndex,
                    skipFirstUnlabeled: customHTTPMethod
                )

                // Per-route @Middleware runs before @AuthMiddleware so rate-limiters and logging
                // see unauthenticated traffic too.
                let routeMiddlewares = HTTPMethodMacroUtilities.parseMiddleware(from: funcDecl)
                let authMiddlewares = HTTPMethodMacroUtilities.parseAuthMiddleware(from: funcDecl)?.middlewares ?? []

                return (funcDecl, httpMethod, route.routeRegistrationSegments, routeMiddlewares, authMiddlewares)
            }

            return nil
        }

        // Generate the RouteCollection boot function
        var registrationBody = ""

        // Build the base route builder: type-level middleware (if any) wraps `routes`, then the path prefix.
        // Order: routes -> grouped(typeMW...) -> grouped(prefix...). Middleware runs before path matching.
        var baseBuilder = "routes"
        if !typeMiddlewares.isEmpty {
            let typeMWList = typeMiddlewares.joined(separator: ", ")
            registrationBody += """
            let base = routes.grouped(\(typeMWList))

            """
            baseBuilder = "base"
        }
        if !prefix.routeRegistrationSegments.isEmpty {
            let prefixLiteral = prefix.routeRegistrationSegments.joined(separator: "\", \"")
            registrationBody += """
            let group = \(baseBuilder).grouped("\(prefixLiteral)")

            """
            baseBuilder = "group"
        }

        for (functionDeclaration, method, pathComponents, routeMiddlewares, authMiddlewares) in functions {
            let path = pathComponents.joined(separator: "\", \"")
            let methodLower = method.lowercased()

            // Call the function generated by the HTTP Method Macros
            let functionName = "_route_\(functionDeclaration.name.text)"
            let pathRegistration = if path == "" {
                ""
            } else {
                "(\"\(path)\")"
            }

            // Per-route middleware chain: route-level @Middleware first, then @AuthMiddleware middlewares.
            var callChain = baseBuilder
            if !routeMiddlewares.isEmpty {
                callChain += ".grouped(\(routeMiddlewares.joined(separator: ", ")))"
            }
            if !authMiddlewares.isEmpty {
                callChain += ".grouped(\(authMiddlewares.joined(separator: ", ")))"
            }

            registrationBody += """
            \(callChain).\(methodLower)\(pathRegistration) { req async throws -> Response in
                try await self.\(functionName)(req: req)
            }

            """
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
