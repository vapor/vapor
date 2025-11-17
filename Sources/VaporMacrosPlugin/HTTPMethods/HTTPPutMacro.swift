import SwiftSyntax
import SwiftSyntaxMacros
import HTTPTypes

public struct HTTPPutMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        try HTTPMethodMacroUtilities.expansion(of: node, providingPeersOf: declaration, in: context, for: .put)
    }
}
