
public enum Abort: ErrorType {
    case BadRequest
    case NotFound
    case InternalServerError
    case Custom(status: Response.Status, message: String)
}
