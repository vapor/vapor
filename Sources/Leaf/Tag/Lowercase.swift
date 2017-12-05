import Async

public final class Lowercase: Leaf.LeafTag {
    public init() {}
    public func render(parsed: ParsedTag, context: inout LeafData, renderer: LeafRenderer) throws -> Future<LeafData?> {
        try parsed.requireParameterCount(1)
        let string = parsed.parameters[0].string?.lowercased() ?? ""
        return Future(.string(string))
    }
}
