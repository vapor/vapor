import SwiftSyntaxMacros
import SwiftCompilerPlugin

@main
struct VaporMacrosPlugin: CompilerPlugin {
    let providingMacros: [any Macro.Type] = [
        ControllerMacro.self,
        HTTPGetMacro.self,
        HTTPPutMacro.self,
        HTTPPostMacro.self,
        HTTPDeleteMacro.self,
        HTTPPatchMacro.self,
    ]
}
