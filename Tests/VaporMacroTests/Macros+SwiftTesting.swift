import Testing
import SwiftSyntaxMacrosGenericTestSupport

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
