#if !swift(>=3.0)
	typealias ErrorProtocol = ErrorType
#endif

public enum Abort: ErrorProtocol {
    case BadRequest
    case NotFound
    case InternalServerError
    case Custom(status: Response.Status, message: String)
}
