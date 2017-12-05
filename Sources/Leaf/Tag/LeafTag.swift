import Async
import Foundation

public protocol LeafTag {
    func render(
        parsed: ParsedTag,
        context: LeafContext,
        renderer: LeafRenderer
    ) throws -> Future<LeafData?>
}

// MARK: Global

public var defaultTags: [String: LeafTag] {
    return [
        "": Print(),
        "ifElse": IfElse(),
        "loop": Loop(),
        "comment": Comment(),
        "contains": Contains(),
        "lowercase": Lowercase(),
        "uppercase": Uppercase(),
        "capitalize": Capitalize(),
        "count": Count(),
        "set": Var(),
        "get": Raw(),
        "embed": Embed(),
    ]
}
