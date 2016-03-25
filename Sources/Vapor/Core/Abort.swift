public enum Abort: ErrorProtocol {
    case BadRequest
    case NotFound
    case InternalServerError
    case Custom(status: Response.Status, message: String)
}
