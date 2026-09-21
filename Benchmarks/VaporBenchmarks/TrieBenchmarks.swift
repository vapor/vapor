import Benchmark
import Logging
import RoutingKit

// Build routers, paths and the no-op logger before timing; each lookup gets a fresh capture bag.
func trieBenchmarks() {
    let logger = Logger(label: "trie-benchmark")
    func measure(
        _ name: String, path: [String], expected: Int?, insensitive: Bool = false,
        captures: [String: String] = [:], catchall: [String] = [],
        routes: [(Int, [PathComponent])]
    ) {
        var builder = TrieRouterBuilder<Int>(config: .init(isCaseInsensitive: insensitive))
        for (output, route) in routes { builder.register(output, at: route) }
        let router = builder.build()
        var check = Parameters(logger)
        precondition(router.route(path: path, parameters: &check) == expected, name)
        for (key, value) in captures { precondition(check.get(key) == value, name) }
        precondition(check.getCatchall() == catchall, name)
        Benchmark("trie.\(name)") { benchmark in
            for _ in benchmark.scaledIterations {
                var parameters = Parameters(logger)
                blackHole(router.route(path: path, parameters: &parameters))
                blackHole(parameters)
            }
        }
    }
    measure(
        "static", path: ["api", "items", "list"], expected: 1,
        routes: [(1, ["api", "items", "list"])])
    measure(
        "parameter", path: ["users", "42"], expected: 1, captures: ["id": "42"],
        routes: [(1, ["users", ":id"])])
    measure(
        "long-parameter", path: ["users", "a-long-user-identifier-without-escapes"], expected: 1,
        captures: ["id": "a-long-user-identifier-without-escapes"],
        routes: [(1, ["users", ":id"])])
    measure(
        "encoded-parameter", path: ["users", "hello%20world"], expected: 1, captures: ["id": "hello world"],
        routes: [(1, ["users", ":id"])])
    measure(
        "three-parameters", path: ["org", "vapor", "repo", "vapor", "issue", "42"], expected: 1,
        captures: ["org": "vapor", "repo": "vapor", "issue": "42"],
        routes: [(1, ["org", ":org", "repo", ":repo", "issue", ":issue"])])
    measure(
        "catchall-matched", path: ["files", "a", "b", "c"], expected: 1, catchall: ["a", "b", "c"],
        routes: [(1, ["files", "**"])])
    measure(
        "catchall-bypassed", path: ["files", "fixed", "end"], expected: 2,
        routes: [(1, ["files", "**"]), (2, ["files", "fixed", "end"])])
    measure(
        "nested-catchalls", path: ["files", "fixed", "end", "a"], expected: 3, catchall: ["end", "a"],
        routes: [(1, ["**"]), (2, ["files", "**"]), (3, ["files", "fixed", "**"])])
    measure(
        "partial-alternatives-bypassed", path: ["files", "fixed.txt", "end"], expected: 1,
        routes: [
            (1, ["files", "fixed.txt", "end"]), (2, ["files", ":{name}.txt", "other"]),
            (3, ["files", ":{name}.{ext}", "else"]),
        ])
    measure(
        "partial-fallback", path: ["files", "fixed.txt", "end"], expected: 2, captures: ["name": "fixed"],
        routes: [(1, ["files", "fixed.txt", "dead"]), (2, ["files", ":{name}.txt", "end"])])
    measure(
        "partial-match", path: ["files", "report.json"], expected: 1, captures: ["name": "report", "ext": "json"],
        routes: [(1, ["files", ":{name}.{ext}"])])
    measure(
        "partial-mismatch", path: ["files", "report.json"], expected: nil,
        routes: [(1, ["files", ":{name}.txt"])])
    measure(
        "wildcard-backtrack", path: ["files", "fixed", "end"], expected: 2, captures: ["name": "fixed"],
        routes: [(1, ["files", "fixed", "dead"]), (2, ["files", ":name", "end"])])
    measure(
        "case-insensitive", path: ["FILES", "REPORT"], expected: 1, insensitive: true, captures: ["name": "REPORT"],
        routes: [(1, ["files", ":name"])])
    measure(
        "static-miss", path: ["api", "unknown"], expected: nil,
        routes: [(1, ["api", "items"])])
    measure(
        "encoded-catchall", path: ["files", "hello%20world", "a%2Fb"], expected: 1,
        catchall: ["hello world", "a/b"], routes: [(1, ["files", "**"])])
    measure(
        "anonymous-wildcard", path: ["files", "anything", "end"], expected: 1,
        routes: [(1, ["files", "*", "end"])])
    for count in [200, 1000] {
        let routes: [(Int, [PathComponent])] = (0..<count).map { index in
            (index, ["api", .constant("resource\(index)"), "detail"])
        }
        measure(
            "hit-among-\(count)-routes", path: ["api", "resource\(count - 1)", "detail"],
            expected: count - 1, routes: routes)
    }

}
