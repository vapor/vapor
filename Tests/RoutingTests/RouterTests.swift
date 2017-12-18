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

        let path: [PathComponent.Parameter] = [.string("foo"), .string("bar"), .string("baz")]

        let route = Route<Int>(path: [.constants(path), .parameter(.string(User.uniqueSlug))], output: 42)
        router.register(route: route)

        let container = BasicContainer(config: Config(), environment: .development, services: Services(), on: DispatchEventLoop(label: "unit-test"))
        let params = Params()
        XCTAssertEqual(router.route(path: path + [.string("Tanner")], parameters: params), 42)
        try XCTAssertEqual(params.parameter(User.self, using: container).blockingAwait().name, "Tanner")
    }


    static let allTests = [
        ("testRouter", testRouter),
    ]
}

final class Params: ParameterContainer {
    var parameters: Parameters = []
    init() {}
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
