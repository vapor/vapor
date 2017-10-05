import Async

public final class Print: Tag {
    public init() { }

    public func render(parsed: ParsedTag, context: inout LeafData, renderer: Renderer) throws -> Future<LeafData?> {
        try parsed.requireNoBody()
        try parsed.requireParameterCount(1)
        let string = parsed.parameters[0].string ?? ""
        let promise = Promise(LeafData?.self)
        promise.complete(.string(string.htmlEscaped()))
        return promise.future
    }
}

