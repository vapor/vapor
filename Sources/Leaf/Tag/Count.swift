import Core

public final class Count: Leaf.Tag {
    init() {}
    
    public func render(parsed: ParsedTag, context: inout Context, renderer: Renderer) throws -> Future<Context?> {
        let promise = Promise(Context?.self)
        try parsed.requireParameterCount(1)

        switch parsed.parameters[0] {
        case .dictionary(let dict):
            promise.complete(.int(dict.values.count))
        case .array(let arr):
            promise.complete(.int(arr.count))
        default:
            promise.complete(.null)
        }

        return promise.future
    }
}

