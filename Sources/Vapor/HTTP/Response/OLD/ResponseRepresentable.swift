/**
    Any data structure that complies to this protocol
    can be returned to generic Vapor closures or route handlers.

    ```app.get("/") { request in
        return object //must be of type `ResponseRepresentable`
    }```
*/
public protocol ResponseRepresentable {
    func makeResponse() throws -> HTTP.Response
}

///Allows responses to be returned through closures
extension HTTP.Response: ResponseRepresentable {
    public func makeResponse() -> HTTP.Response {
        return self
    }
}

///Allows Swift Strings to be returned through closures
extension Swift.String: ResponseRepresentable {
    public func makeResponse() -> HTTP.Response {
        fatalError("// TODO:")
//        return Response(status: .ok, text: self)
    }
}
