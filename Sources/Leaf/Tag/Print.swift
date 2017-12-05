import Async

public final class Print: LeafTag {
    public init() { }

    public func render(parsed: ParsedTag, context: LeafContext, renderer: LeafRenderer) throws -> Future<LeafData?> {
        try parsed.requireNoBody()
        try parsed.requireParameterCount(1)
        let string = parsed.parameters[0].string ?? ""
        let promise = Promise(LeafData?.self)
        promise.complete(.string(string.htmlEscaped()))
        return promise.future
    }
}

