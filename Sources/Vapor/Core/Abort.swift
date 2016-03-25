/**
    A handful of standard errors that can be thrown
    in any Vapor closure by calling `throw Abort.<case>`.
    These errors can be caught in Middleware to give
    a desired response.
*/
public enum Abort: ErrorProtocol {
    case BadRequest
    case NotFound
    case InternalServerError
    case Custom(status: Response.Status, message: String)
}
