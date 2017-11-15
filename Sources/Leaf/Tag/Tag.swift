import Async
import Foundation

public protocol Tag {
    func render(
        parsed: ParsedTag,
        context: inout LeafData,
        renderer: Renderer
    ) throws -> Future<LeafData?>
}

// MARK: Global

public var defaultTags: [String: Tag] {
    return [
        "": Print(),
        "ifElse": IfElse(),
        "var": Var(),
        "embed": Embed(),
        "loop": Loop(),
        "comment": Comment(),
        "contains": Contains(),
        "lowercase": Lowercase(),
        "count": Count(),
        "raw": Raw(),
        // import/export
        "export": Var(),
        "import": Embed()
    ]
}
