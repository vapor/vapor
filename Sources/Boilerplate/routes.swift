import Vapor

let http = HTTPResponse()

final class Routes: RouteCollection {
    let app: Application

    init(app: Application) {
        self.app = app
    }

    func boot(router: Router) throws {
//        router.get("hello") { req -> Future<Response> in
//            let res = try req.make(Client.self).get("http://httpbin.org/ip").await(on: req)
//            return Future(res)
//        }

        router.get("ping") { req in
            return "123" as StaticString
        }

//        router.get("ip") { req -> Future<String> in
//            return try req.make(Client.self).get("http://httpbin.org/ip").map(to: String.self) { res in
//                print(res)
//                debugPrint(res)
//                return "done"
//            }
//        }
    }
}
