import Async
import Foundation

public protocol LeafTag {
    func render(
        parsed: ParsedTag,
        context: inout LeafData,
        renderer: LeafRenderer
    ) throws -> Future<LeafData?>
}

// MARK: Global

public var defaultTags: [String: LeafTag] {
    return [
        "": Print(),
        "ifElse": IfElse(),
        "embed": Embed(),
        "loop": Loop(),
        "comment": Comment(),
        "contains": Contains(),
        "lowercase": Lowercase(),
        "count": Count(),
        "var": Var(),
        "raw": Raw(),
        // import/export
        "export": Var(),
        "import": Raw()
    ]
}
