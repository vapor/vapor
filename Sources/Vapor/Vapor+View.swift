import Async
import HTTP
import Leaf

extension ViewRenderer {
    /// Make a view for a given request.
    /// The dispatch queue required for the view renderer will
    /// be extracted from the request.
    public func make(_ path: String, context: Encodable, for req: Request) throws -> Future<View> {
        return try make(path, context: context, on: req.requireQueue())
    }
}

