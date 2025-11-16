import SwiftSyntaxMacros
import SwiftCompilerPlugin

@main
struct VaporMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        // Register your macros here
        ControllerMacro.self,
        HTTPGetMacro.self,
    ]
}