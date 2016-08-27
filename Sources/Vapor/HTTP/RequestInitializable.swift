import HTTP

/**
    Objects that conform to RequestInitializable
    can be easily created from an incoming request.
 
    This is useful for encapsulating request data
    parsing into models or types.
 
        ex: LoginRequest, PostSubmissionRequest
*/
public protocol RequestInitializable {
    init(request: Request) throws
}
