import XCTest
import Engine
import Routing

class RouteBuilderTests: XCTestCase {
    static var allTests = [
        ("testGroup", testGroup),
        ("testGroupWithPrefix", testGroupWithPrefix),
        ("testGroupWithMap", testGroupWithMap)
    ]

    func testGroup() {
        let router = Router<Int>()
        router.group(prefix: [nil, nil], path: ["baz"], map: nil, closure: { group in
            group.add(path: ["foo", "bar", "ferret", "42"], value: 1337)
        })

        let container = BasicContainer()
        let output = router.route(path: ["foo", "bar", "baz", "ferret", "42"], with: container)
        XCTAssertEqual(output, 1337)
    }

    func testGroupWithPrefix() {
        let router = Router<Int>()
        router.group(prefix: ["FOO", nil], path: ["baz"], map: nil, closure: { group in
            group.add(path: ["foo", "bar", "ferret", "42"], value: 1337)
        })

        let container = BasicContainer()
        let output = router.route(path: ["FOO", "bar", "baz", "ferret", "42"], with: container)
        XCTAssertEqual(output, 1337)
    }

    func testGroupWithMap() {
        let router = Router<Int>()
        router.group(prefix: [nil, nil], path: ["baz"], map: { value in
            if value == 1337 {
                return 42
            }
            return value
        }, closure: { group in
            group.add(path: ["foo", "bar", "ferret", "42"], value: 1337)
        })

        let container = BasicContainer()
        let output = router.route(path: ["foo", "bar", "baz", "ferret", "42"], with: container)
        XCTAssertEqual(output, 42)
    }
}
