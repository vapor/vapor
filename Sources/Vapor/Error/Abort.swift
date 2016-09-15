import HTTP

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

extension Abort {
    func makeJSONResponse(status: Status, message: String) throws -> Response {
        let json = try JSON(node: [
            "error": true,
            "message": "\(message)"
            ])
        let data = try json.makeBytes()
        let response = Response(status: status, body: .data(data))
        response.headers["Content-Type"] = "application/json; charset=utf-8"
        return response
    }

    func makeHTMLResponse(status: Status, message: String) throws -> Response {
        return ErrorView.shared.makeResponse(status, message)
    }
}
