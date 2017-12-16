import Vapor

let http = HTTPResponse()

final class Routes: RouteCollection {
    let app: Application

    init(app: Application) {
        self.app = app
    }

    func boot(router: Router) throws {
        router.get("hello") { req -> Future<Response> in
            let res = req.makeResponse()
            res.http = http
            return Future(res)
        }
    }
}
