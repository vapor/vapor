import HTTP
import Turnstile

class AuthMiddlewareResponser: Responder {
    func respond(to request: Request) throws -> Response {
        try request.auth.login(UsernamePassword(username: "username", password: "password"))
        return "test".makeResponse()
    }
}
