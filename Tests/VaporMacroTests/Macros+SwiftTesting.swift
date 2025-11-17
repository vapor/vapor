import Testing
import SwiftSyntaxMacrosGenericTestSupport
import SwiftSyntaxMacroExpansion
import VaporMacrosPlugin

enum FailureHandler {
    static func instance(_ spec: TestFailureSpec) {
        Issue.record(
            Comment(rawValue: spec.message),
            sourceLocation: .init(
                fileID: spec.location.fileID,
                filePath: spec.location.filePath,
                line: spec.location.line,
                column: spec.location.column
            )
        )
    }
}

let testMacros: [String: MacroSpec] = [
    "GET": MacroSpec(type: HTTPGetMacro.self),
    "POST": MacroSpec(type: HTTPPostMacro.self),
    "PUT": MacroSpec(type: HTTPPutMacro.self),
    "DELETE": MacroSpec(type: HTTPDeleteMacro.self),
    "PATCH": MacroSpec(type: HTTPPatchMacro.self),
    "HTTP": MacroSpec(type: HTTPMethodMacro.self),
    "Controller": MacroSpec(type: ControllerMacro.self),
]
