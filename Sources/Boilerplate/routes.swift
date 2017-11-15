import HTTP
import Routing
import Vapor

final class Routes: RouteCollection {
    let app: Application

    init(app: Application) {
        self.app = app
    }

    func boot(router: Router) throws {
        let body = try "Hello, world!".makeBody()
        router.get("hello") { req in
            return Response(status: .ok, body: body)
        }
    }
}
