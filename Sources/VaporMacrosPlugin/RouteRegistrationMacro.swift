import SwiftSyntax
import SwiftSyntaxMacros
import HTTPTypes

public struct RouteRegistrationMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let macroName = node.attributeName.trimmedDescription

        guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
            throw MacroError.notAFunction(macroName)
        }

        let arguments: LabeledExprListSyntax? = switch node.arguments {
        case .argumentList(let arguments): arguments
        default: nil
        }

        let routeHandler = funcDecl.name.trimmedDescription

        // Parse path components and parameter types
        var pathParameters: [String] = []

        guard let arguments, arguments.count >= 2 else {
            throw MacroError.missingArguments("Internal Error")
        }

        var routeBuilder: String? = nil
        var httpMethod: HTTPRequest.Method? = nil

        for (index, argument) in arguments.enumerated() {
            // First is the route builder
            if index == 0 {
                routeBuilder = argument.expression.trimmedDescription
                continue
            }
            
            // Second is the HTTP Method
            if index == 1 {
                let httpMethodStr = argument.expression.trimmedDescription.lowercased()

                guard let parsedHTTPMethod = HTTPRequest.Method(rawValue: httpMethodStr) else {
                    throw MacroError.missingArguments("Internal Error")
                }
                
                httpMethod = parsedHTTPMethod
                continue
            }

            pathParameters.append(argument.expression.trimmedDescription)
        }

        guard let routeBuilder, let httpMethod else {
            throw MacroError.missingArguments("Internal Error")
        }

        // // Generate wrapper that extracts path parameters
        // var parameterExtraction = ""
        // var callParameters = "req: req"

        // for (index, paramType) in parameterTypes.enumerated() {
        //     let functionParameterName = funcParameters[index].firstName.text
        //     let parameterName = "\(paramType.lowercased())\(index)"
        //     parameterExtraction += """
        //     let \(parameterName) = try req.parameters.require("\(paramType.lowercased())\(index)", as: \(paramType).self)
            
        //     """
        //     callParameters += ", \(functionParameterName): \(parameterName)"
        // }

        // let isAsyncFunction = funcDecl.signature.effectSpecifiers?.asyncSpecifier != nil

        // let wrapperFunc: DeclSyntax = """
        // @Sendable func _route_\(raw: functionName)(req: Request) async throws -> Response {
        //     \(raw: parameterExtraction)let result: some ResponseEncodable = try \(raw: isAsyncFunction ? "await " : "")\(raw: functionName)(\(raw: callParameters))
        //     return try await result.encodeResponse(for: req)
        // }
        // """

        // if let routeRegistrationVariable {
        //     var currentDynamicPathParameterIndex = 0
        //     var pathComponents: [String] = []
        //     if let arguments {
        //         for (index, arg) in arguments.enumerated() {
        //             // Discard the first one (the place to register the routes) and if we're a custom HTTP method, discard the next one
        //             if index == 0 || customHTTPMethod && index == 1 {
        //                 continue
        //             }
        //             let exprStr = arg.expression.description.trimmingCharacters(in: .whitespacesAndNewlines)

        //             // Check if it's a type (contains .self)
        //             if exprStr.hasSuffix(".self") {
        //                 let typeName = exprStr.replacing(".self", with: "")
        //                 pathComponents.append(":\(typeName.lowercased())\(currentDynamicPathParameterIndex)")
        //                 currentDynamicPathParameterIndex += 1
        //             } else {
        //                 // It's a string literal
        //                 let cleaned = exprStr.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        //                 pathComponents.append(cleaned)
        //             }
        //         }
        //     }

        //     let path = pathComponents.joined(separator: "\", \"")
        //     let pathRegistration = if path == "" {
        //         ""
        //     } else {
        //         ", \"\(path)\""
        //     }
        //     let routeRegistration: DeclSyntax = """
        //     @RouteRegistration(\(raw: routeRegistrationVariable), method: .\(raw: method.rawValue)\(raw: pathRegistration))
        //     @Sendable func _route_\(raw: functionName)(req: Request) async throws -> Response {
        //         \(raw: parameterExtraction)let result: some ResponseEncodable = try \(raw: isAsyncFunction ? "await " : "")\(raw: functionName)(\(raw: callParameters))
        //         return try await result.encodeResponse(for: req)
        //     }
        //     """
        //     return [routeRegistration]
        // }

        // return [wrapperFunc]

        let pathParameterValue: String
        if pathParameters.count > 0 {
            pathParameterValue = ", \(pathParameters.joined(separator: ","))"
        } else {
            pathParameterValue = ""
        }

        let routeRegistration: DeclSyntax = """
        let _ = \(raw: routeBuilder).on(.\(raw: httpMethod.rawValue)\(raw: pathParameterValue), use: \(raw: routeHandler))
        """
        return [routeRegistration]
    }
}
