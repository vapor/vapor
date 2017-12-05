import Async

public final class Count: Leaf.LeafTag {
    init() {}
    
    public func render(parsed: ParsedTag, context: LeafContext, renderer: LeafRenderer) throws -> Future<LeafData?> {
        let promise = Promise(LeafData?.self)
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

