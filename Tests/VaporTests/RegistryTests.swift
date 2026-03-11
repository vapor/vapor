import HTTPTypes
import NIOConcurrencyHelpers
import RoutingKit
import Testing
import Vapor
import VaporTesting

@Suite("Registry Tests")
struct RegistryTests {
    @Test("Register and retrieve values")
    func registerAndRetrieve() async throws {
        let registry = Registry<String, Int>()
        registry.register("a", 1)
        registry.register("b", 2)

        #expect(registry["a"] == 1)
        #expect(registry["b"] == 2)
        #expect(registry["c"] == nil)
        #expect(registry.count == 2)
    }

    @Test("Remove values")
    func removeValues() async throws {
        let registry = Registry<String, Int>()
        registry.register("a", 1)
        registry.register("b", 2)

        let removed = registry.remove("a")
        #expect(removed == 1)
        #expect(registry["a"] == nil)
        #expect(registry.count == 1)

        let notFound = registry.remove("nonexistent")
        #expect(notFound == nil)
    }

    @Test("Replace existing value")
    func replaceExisting() async throws {
        let registry = Registry<String, Int>()
        registry.register("a", 1)
        registry.register("a", 42)

        #expect(registry["a"] == 42)
        #expect(registry.count == 1)
    }

    @Test("All returns snapshot")
    func allSnapshot() async throws {
        let registry = Registry<String, Int>()
        registry.register("a", 1)
        registry.register("b", 2)

        let snapshot = registry.all
        #expect(snapshot == ["a": 1, "b": 2])
    }

    @Test("Contains check")
    func contains() async throws {
        let registry = Registry<String, Int>()
        registry.register("a", 1)

        #expect(registry.contains("a"))
        #expect(!registry.contains("b"))
    }

    @Test("isEmpty and clear")
    func isEmptyAndClear() async throws {
        let registry = Registry<String, Int>()
        #expect(registry.isEmpty)

        registry.register("a", 1)
        #expect(!registry.isEmpty)

        registry.clear()
        #expect(registry.isEmpty)
        #expect(registry.count == 0)
    }

    @Test("Send to specific entry")
    func sendToEntry() async throws {
        let registry = Registry<String, Int>()
        registry.register("a", 42)

        let received = NIOLockedValueBox(0)
        try await registry.send(to: "a") { value in
            received.withLockedValue { $0 = value }
        }
        #expect(received.withLockedValue { $0 } == 42)
    }

    @Test("Send to missing entry throws notFound")
    func sendToMissing() async throws {
        let registry = Registry<String, Int>()

        await #expect(throws: RegistryError.notFound) {
            try await registry.send(to: "missing") { _ in }
        }
    }

    @Test("Broadcast to all entries")
    func broadcast() async throws {
        let registry = Registry<String, Int>()
        registry.register("a", 1)
        registry.register("b", 2)
        registry.register("c", 3)

        let collected = NIOLockedValueBox<[Int]>([])
        try await registry.broadcast { value in
            collected.withLockedValue { $0.append(value) }
        }

        let result = collected.withLockedValue { $0.sorted() }
        #expect(result == [1, 2, 3])
    }

    @Test("Application registry returns same instance")
    func applicationRegistrySameInstance() async throws {
        try await withApp { app in
            let reg1: Registry<String, Int> = app.registry(for: "test")
            let reg2: Registry<String, Int> = app.registry(for: "test")

            reg1.register("key", 42)
            #expect(reg2["key"] == 42)
            #expect(reg1 === reg2)
        }
    }

    @Test("Application registries with different names are independent")
    func applicationRegistriesIndependent() async throws {
        try await withApp { app in
            let reg1: Registry<String, Int> = app.registry(for: "one")
            let reg2: Registry<String, Int> = app.registry(for: "two")

            reg1.register("key", 1)
            reg2.register("key", 2)

            #expect(reg1["key"] == 1)
            #expect(reg2["key"] == 2)
            #expect(reg1 !== reg2)
        }
    }

    @Test("Request registry forwards to application")
    func requestRegistryForwards() async throws {
        try await withApp { app in
            let appRegistry: Registry<String, Int> = app.registry(for: "shared")
            appRegistry.register("key", 99)

            app.get("test") { req in
                let reqRegistry: Registry<String, Int> = req.registry(for: "shared")
                return String(reqRegistry["key"] ?? -1)
            }

            try await app.testing().test(.get, "test") { res in
                #expect(res.body.string == "99")
            }
        }
    }

    @Test("Concurrent access is safe")
    func concurrentAccess() async throws {
        let registry = Registry<Int, String>()

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    registry.register(i, "value-\(i)")
                }
            }
        }

        #expect(registry.count == 100)

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<50 {
                group.addTask {
                    registry.remove(i)
                }
            }
        }

        #expect(registry.count == 50)
    }
}
