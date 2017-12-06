import Async

public final class Uppercase: Leaf.LeafTag {
    public init() {}
    public func render(parsed: ParsedTag, context: LeafContext, renderer: LeafRenderer) throws -> Future<LeafData?> {
        try parsed.requireParameterCount(1)
        let string = parsed.parameters[0].string?.uppercased() ?? ""
        return Future(.string(string))
    }
}
