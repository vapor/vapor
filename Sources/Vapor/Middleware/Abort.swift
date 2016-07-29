import Engine

/**
    A handful of standard errors that can be thrown
    in any Vapor closure by calling `throw Abort.<case>`.
    These errors can be caught in Middleware to give
    a desired response.
*/
public enum Abort: Swift.Error {
    case badRequest
    case notFound
    case serverError
    case custom(status: Status, message: String)
}
