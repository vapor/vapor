/**
    Intercept and modify `Request`s and `Response`s
    using middleware. Create a class that conforms to
    the `Middleware` protocol, then append the class
    to the `Server`s `middleware` array.
*/
public protocol Middleware {

    /**
        Here is where you implement your custom `Middleware`
        logic. Look at the `SessionMiddleware` to see an
        example of `Middleware` being used.

        Call `handler(request)` somewhere inside your custom
        handler to get the `Response` object.
    */
    static func handle(handler: Request.Handler, for application: Application) -> Request.Handler

}
