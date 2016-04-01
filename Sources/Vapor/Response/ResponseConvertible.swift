/**
    Any data structure that complies to this protocol
    can be returned to generic Vapor closures or route handlers.

    ```app.get("/") { request in
        return object //must be of type `ResponseConvertible`
    }```
*/
public protocol ResponseRepresentable {
    func makeResponse() -> Response
}

///Allows responses to be returned through closures
extension Response: ResponseRepresentable {
    public func makeResponse() -> Response {
        return self
    }
}

///Allows Swift Strings to be returned through closures
extension Swift.String: ResponseRepresentable {
    public func makeResponse() -> Response {
        return Response(status: .ok, text: self)
    }
}
