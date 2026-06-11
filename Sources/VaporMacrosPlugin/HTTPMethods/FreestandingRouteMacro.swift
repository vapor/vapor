import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxBuilder
import Foundation
import HTTPTypes

enum FreestandingRouteMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext,
        for method: HTTPRequest.Method,
        customHTTPMethod: Bool = false
    ) throws -> [DeclSyntax] {
        let arguments = node.arguments

        // Extract the route builder (the `on:` argument) - required for freestanding
        var routeRegistrationVariable: String? = nil
        var pathArguments: [LabeledExprSyntax] = []
        var skippedHTTPMethod = false

        for argument in arguments {
            if argument.label?.text == "on" {
                routeRegistrationVariable = argument.expression.description.trimmingCharacters(in: .whitespacesAndNewlines)
                continue
            }
            // Skip the first non-on: argument for custom HTTP methods (that's the HTTP method itself)
            if customHTTPMethod && !skippedHTTPMethod {
                skippedHTTPMethod = true
                continue
            }
            pathArguments.append(argument)
        }

        guard let routeRegistrationVariable else {
            throw MacroError.missingArguments("Route")
        }

        // Extract the trailing closure
        guard let trailingClosure = node.trailingClosure else {
            throw MacroError.missingArguments("Route")
        }

        // Parse path components and extract parameter types
        var parameterTypes: [String] = []
        var currentDynamicPathParameterIndex = 0
        var pathComponents: [String] = []

        for arg in pathArguments {
            let exprStr = arg.expression.description.trimmingCharacters(in: .whitespacesAndNewlines)

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

        // Build the path registration string
        let path = pathComponents.joined(separator: "\", \"")
        let pathRegistration = if path == "" {
            ""
        } else {
            ", \"\(path)\""
        }

        // Extract parameter names from the closure signature
        var closureParams: [(label: String, name: String)] = []
        if let signature = trailingClosure.signature {
            if case let .parameterClause(parameterClause) = signature.parameterClause {
                for (index, param) in parameterClause.parameters.enumerated() {
                    if index == 0 { continue } // Skip `req`
                    let name = param.secondName?.text ?? param.firstName.text
                    closureParams.append((label: name, name: name))
                }
            }
        }

        // Build parameter extraction code
        var parameterExtraction = ""
        var callParameters = ""

        for (index, paramType) in parameterTypes.enumerated() {
            let parameterName = "\(paramType.lowercased())\(index)"
            parameterExtraction += """
            let \(parameterName) = try req.parameters.require("\(parameterName)", as: \(paramType).self)

            """
            callParameters += ", \(parameterName)"
        }

        // Determine if the closure is async
        let isAsync = trailingClosure.signature?.effectSpecifiers?.asyncSpecifier != nil

        // Generate a unique name for the handler binding
        let uniqueName = context.makeUniqueName("_handler")

        let registration: DeclSyntax

        if parameterTypes.isEmpty {
            registration = """
            let \(uniqueName) = \(raw: routeRegistrationVariable).on(.\(raw: method.rawValue.lowercased())\(raw: pathRegistration)) { req -> Response in
                let _closure = \(trailingClosure)
                let result: some ResponseEncodable = try \(raw: isAsync ? "await " : "")_closure(req)
                return try await result.encodeResponse(for: req)
            }
            """
        } else {
            registration = """
            let \(uniqueName) = \(raw: routeRegistrationVariable).on(.\(raw: method.rawValue.lowercased())\(raw: pathRegistration)) { req -> Response in
                \(raw: parameterExtraction)let _closure = \(trailingClosure)
                let result: some ResponseEncodable = try \(raw: isAsync ? "await " : "")_closure(req\(raw: callParameters))
                return try await result.encodeResponse(for: req)
            }
            """
        }

        return [registration]
    }
}

// MARK: - Concrete Freestanding Macros

public struct FreestandingGetMacro: DeclarationMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        try FreestandingRouteMacro.expansion(of: node, in: context, for: .get)
    }
}

public struct FreestandingPostMacro: DeclarationMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        try FreestandingRouteMacro.expansion(of: node, in: context, for: .post)
    }
}

public struct FreestandingPutMacro: DeclarationMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        try FreestandingRouteMacro.expansion(of: node, in: context, for: .put)
    }
}

public struct FreestandingDeleteMacro: DeclarationMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        try FreestandingRouteMacro.expansion(of: node, in: context, for: .delete)
    }
}

public struct FreestandingPatchMacro: DeclarationMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        try FreestandingRouteMacro.expansion(of: node, in: context, for: .patch)
    }
}

public struct FreestandingHTTPMethodMacro: DeclarationMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let arguments = node.arguments
        guard let firstArg = arguments.first else {
            throw MacroError.missingArguments("Route")
        }

        let methodText = firstArg.expression.description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let memberAccess = firstArg.expression.as(MemberAccessExprSyntax.self) else {
            throw MacroError.invalidHTTPMethod(methodText)
        }
        let baseName = memberAccess.declName.baseName.text
        let methodName = baseName.prefix(1).uppercased() + baseName.dropFirst()
        guard let method = HTTPRequest.Method(rawValue: methodName) else {
            throw MacroError.invalidHTTPMethod(methodText)
        }

        return try FreestandingRouteMacro.expansion(of: node, in: context, for: method, customHTTPMethod: true)
    }
}
