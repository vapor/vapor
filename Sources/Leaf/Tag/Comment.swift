import Async

public final class Comment: Tag {
    public init() {}
    public func render(parsed: ParsedTag, context: inout LeafData, renderer: Renderer) throws -> Future<LeafData?> {
        let promise = Promise(LeafData?.self)
        promise.complete(.string(""))
        return promise.future
    }
}
