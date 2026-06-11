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
        HTTPMethodMacro.self,
        FreestandingGetMacro.self,
        FreestandingPostMacro.self,
        FreestandingPutMacro.self,
        FreestandingDeleteMacro.self,
        FreestandingPatchMacro.self,
        FreestandingHTTPMethodMacro.self,
        AuthMiddlewareMacro.self,
    ]
}
