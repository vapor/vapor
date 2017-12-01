import Vapor

final class Routes: RouteCollection {
    let app: Application

    init(app: Application) {
        self.app = app
    }

    func boot(router: Router) throws {
        router.get("hello") { req in
            return "Hello, world!"
        }
    }
}
