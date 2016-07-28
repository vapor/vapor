import XCTest
import Branches

class BranchTests: XCTestCase {
    func testSimple() {
        let base = Branch<String>(name: "[base]", output: nil)
        base.extend(["a", "b", "c"], output: "abc")
        let result = base.fetch(["a", "b", "c"])
        XCTAssert(result?.branch.output == "abc")
    }

    func testWildcard() {
        let base = Branch<String>(name: "[base]", output: nil)
        base.extend(["a", "b", "c", "*"], output: "abc")
        let result = base.fetch(["a", "b", "c"])
        XCTAssert(result?.branch.output == "abc")
    }

    func testWildcardTrailing() {
        let base = Branch<String>(name: "[base]", output: nil)
        base.extend(["a", "b", "c", "*"], output: "abc")
        guard let result = base.fetch(["a", "b", "c", "d", "e", "f"]) else {
            XCTFail("invalid wildcard fetch")
            return
        }

        XCTAssert(result.branch.output == "abc")
        XCTAssert(Array(result.remaining) == ["d", "e", "f"])
    }

    func testParams() {
        let base = Branch<String>(name: "[base]", output: nil)
        base.extend([":a", ":b", ":c", "*"], output: "abc")
        let path = ["zero", "one", "two", "d", "e", "f"]
        guard let result = base.fetch(path) else {
            XCTFail("invalid wildcard fetch")
            return
        }

        let params = result.branch.slugs(for: path)
        XCTAssert(params["a"] == "zero")
        XCTAssert(params["b"] == "one")
        XCTAssert(params["c"] == "two")
        XCTAssert(result.branch.output == "abc")
        XCTAssert(Array(result.remaining) == ["d", "e", "f"])
    }

    func testOutOfBoundsParams() {
        let base = Branch<String>(name: "[base]", output: nil)
        base.extend([":a", ":b", ":c", "*"], output: "abc")
        let path = ["zero", "one", "two", "d", "e", "f"]
        guard let result = base.fetch(path) else {
            XCTFail("invalid wildcard fetch")
            return
        }

        let params = result.branch.slugs(for: ["zero", "one"])
        XCTAssert(params["a"] == "zero")
        XCTAssert(params["b"] == "one")
        XCTAssert(params["c"] == nil)
        XCTAssert(result.branch.output == "abc")
        XCTAssert(Array(result.remaining) == ["d", "e", "f"])
    }

    func testLeadingPath() {
        let base = Branch<String>(name: "[base]", output: nil)
        let subBranch = base.extend([":a", ":b", ":c", "*"], output: "abc")
        XCTAssert(subBranch.path == [":a", ":b", ":c", "*"])
    }

    func testEmpty() {
        let base = Branch<String>(name: "[base]", output: nil)
        base.extend(["a", "b", "c"], output: "abc")
        let result = base.fetch(["z"])
        XCTAssert(result == nil)

    }
}
