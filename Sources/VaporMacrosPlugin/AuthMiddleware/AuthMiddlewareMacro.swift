import SwiftSyntax
import SwiftSyntaxMacros

public struct AuthMiddlewareMacro: PeerMacro {
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
