import Core

public final class Comment: Tag {
    public init() {}
    public func render(parsed: ParsedTag, context: inout Context, renderer: Renderer) throws -> Future<Context?> {
        let promise = Promise(Context?.self)
        promise.complete(.string(""))
        return promise.future
    }
}
