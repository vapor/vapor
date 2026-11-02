public import SwiftSyntax
public import SwiftSyntaxMacros

public struct FreestandingMiddlewareMacro: DeclarationMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        try GroupingMacroHelpers.validateGroupContext(in: context)
        // @Controller lifts grouped handlers. Declaring no generated names here avoids
        // a name-lookup cycle when these arguments refer to controller properties.
        return []
    }
}
