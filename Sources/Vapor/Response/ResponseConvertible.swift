/**
    Any data structure that complies to this protocol
    can be returned to generic Vapor closures or route handlers.

    ```app.get("/") { request in 
        return object //must be of type `ResponseConvertible`
    }```
*/
public protocol ResponseConvertible {
    func response() -> Response
}

///Allows responses to be returned through closures
extension Response: ResponseConvertible {
    public func response() -> Response {
        return self
    }
}

///Allows Swift Strings to be returned through closures
extension Swift.String: ResponseConvertible {
    public func response() -> Response {
        return Response(status: .OK, html: self)
    }
}
