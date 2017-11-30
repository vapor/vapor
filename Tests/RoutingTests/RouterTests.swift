import Async
import Dispatch
import HTTP
import Bits
import Routing
import Service
import XCTest

class RouterTests: XCTestCase {
    func testRouter() throws {
        let router = TrieRouter<Int>()

        let path = [Data("foo".utf8), Data("bar".utf8), Data("baz".utf8)]

        let route = Route<Int>(path: [.constants(path), .parameter(Data(User.uniqueSlug.utf8))], output: 42)
        router.register(route: route)

        let container = BasicContainer(config: Config(), environment: .development, services: Services(), on: DispatchQueue.global())
        let params = ParameterContainer(container: container)
        XCTAssertEqual(router.route(path: path + [Data("Tanner".utf8)], parameters: params), 42)
        try XCTAssertEqual(params.next(User.self).blockingAwait().name, "Tanner")
    }


    static let allTests = [
        ("testRouter", testRouter),
    ]
}

final class User: Parameter {
    var name: String

    init(name: String) {
        self.name = name
    }

    static func make(for parameter: String, using container: Container) throws -> Future<User> {
        return Future(User(name: parameter))
    }
}
