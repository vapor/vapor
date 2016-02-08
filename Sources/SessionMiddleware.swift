import Foundation

class SessionMiddleware: Middleware {
    func handle(handler: Request -> Response) -> (Request -> Response) {
        return { request in
            Session.start(request)
            
            let response = handler(request)
            
            Session.close(request: request, response: response)
            
            return response
        }
    }
}