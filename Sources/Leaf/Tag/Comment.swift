import Async

public final class Comment: LeafTag {
    public init() {}
    public func render(parsed: ParsedTag, context: inout LeafData, renderer: LeafRenderer) throws -> Future<LeafData?> {
        let promise = Promise(LeafData?.self)
        promise.complete(.string(""))
        return promise.future
    }
}
