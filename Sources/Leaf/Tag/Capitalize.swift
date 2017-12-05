import Async
import Foundation

public final class Capitalize: Leaf.LeafTag {
    public init() {}
    public func render(parsed: ParsedTag, context: LeafContext, renderer: LeafRenderer) throws -> Future<LeafData?> {
        try parsed.requireParameterCount(1)
        let string = parsed.parameters[0].string?.capitalized ?? ""
        return Future(.string(string))
    }
}
