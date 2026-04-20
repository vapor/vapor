import SwiftSyntax
import SwiftSyntaxMacros

public struct MiddlewareMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // This macro is purely declarative — ControllerMacro reads the attached
        // @Middleware attributes (on the type or on member functions) and splices
        // their expressions into `routes.grouped(...)` calls when generating boot.
        []
    }
}
