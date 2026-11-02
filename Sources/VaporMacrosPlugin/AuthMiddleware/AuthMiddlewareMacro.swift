public import SwiftSyntax
public import SwiftSyntaxMacros

public struct AuthMiddlewareMacro: PeerMacro, DeclarationMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        try GroupingMacroHelpers.validateGroupContext(in: context)
        // @Controller lifts grouped handlers. Declaring no generated names here avoids
        // a name-lookup cycle when these arguments refer to controller properties.
        return []
    }

    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // This macro is purely declarative — auth extraction and middleware
        // grouping are handled by HTTP method macros and @Controller
        []
    }
}
