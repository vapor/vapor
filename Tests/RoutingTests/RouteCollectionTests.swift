import XCTest
import Routing

class RouteCollectionTests: XCTestCase {
    static let allTests = [
        ("testSimple", testSimple),
    ]

    func testSimple() {
        let router = Router<Int>()

        let collection = TestRouteCollection()
        router.collection(collection)

        let container = BasicContainer()
        let basic = router.route(path: ["foo", "bar"], with: container)
        XCTAssertEqual(basic, 5)

        let group = router.route(path: ["group", "sub"], with: container)
        XCTAssertEqual(group, 42)
    }
}

final class TestRouteCollection: RouteCollection {
    init() {}
    typealias Wrapped = Int
    func build<Builder: RouteBuilder>(_ builder: Builder) where Builder.Value == Wrapped {
        builder.add(path: ["foo", "bar"], value: 5)

        builder.group(prefix: [], path: ["group"], map: nil, closure: { group in
            group.add(path: ["sub"], value: 42)
        })
    }
}
