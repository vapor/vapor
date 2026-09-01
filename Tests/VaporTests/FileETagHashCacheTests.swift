import Vapor
import VaporTesting
import RoutingKit
import HTTPTypes
import NIOConcurrencyHelpers
import Testing
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

@Suite("File ETag Hash Cache Tests")
struct FileETagHashCacheTests {
    private let modified = Date(timeIntervalSince1970: 1_000)

    @Test("A hash is computed once and then served from the cache")
    func testSecondLookupIsCached() async throws {
        let cache = FileETagHashCache(capacity: 8)
        let computations = NIOLockedValueBox(0)

        for _ in 0..<3 {
            let digest = try await cache.digestHex(forFileAt: "/a", lastModified: modified, size: 10) {
                computations.withLockedValue { $0 += 1 }
                return "digest"
            }
            #expect(digest == "digest")
        }
        #expect(computations.withLockedValue { $0 } == 1)
    }

    @Test("Concurrent misses share a single computation")
    func testConcurrentMissesShareOneComputation() async throws {
        let cache = FileETagHashCache(capacity: 8)
        let computations = NIOLockedValueBox(0)

        // Every caller arrives before the first finishes, so a cache that only dedupes on
        // *completed* work would read the file once per caller.
        let digests = try await withThrowingTaskGroup(of: String.self) { group in
            for _ in 0..<20 {
                group.addTask {
                    try await cache.digestHex(forFileAt: "/a", lastModified: self.modified, size: 10) {
                        computations.withLockedValue { $0 += 1 }
                        try await Task.sleep(for: .milliseconds(50))
                        return "digest"
                    }
                }
            }
            return try await group.reduce(into: [String]()) { $0.append($1) }
        }

        #expect(digests.count == 20)
        #expect(digests.allSatisfy { $0 == "digest" })
        #expect(computations.withLockedValue { $0 } == 1)
    }

    @Test("A failed computation isn't cached and doesn't strand later callers")
    func testFailureIsNotCached() async throws {
        struct HashFailure: Error {}
        let cache = FileETagHashCache(capacity: 8)

        await #expect(throws: HashFailure.self) {
            try await cache.digestHex(forFileAt: "/a", lastModified: self.modified, size: 10) {
                throw HashFailure()
            }
        }
        #expect(await cache.entry(forFileAt: "/a") == nil)

        // A later caller gets to try again rather than inheriting the failure.
        let digest = try await cache.digestHex(forFileAt: "/a", lastModified: modified, size: 10) { "digest" }
        #expect(digest == "digest")
    }

    @Test("A file is rehashed when its modification date or size changes")
    func testGenerationChangeInvalidates() async throws {
        let cache = FileETagHashCache(capacity: 8)

        #expect(try await cache.digestHex(forFileAt: "/a", lastModified: modified, size: 10) { "first" } == "first")

        // Same size, later modification date.
        let touched = modified.addingTimeInterval(1)
        #expect(try await cache.digestHex(forFileAt: "/a", lastModified: touched, size: 10) { "second" } == "second")

        // Same modification date, different size — filesystems that record timestamps to the
        // nearest second report an unchanged date for an edit made moments later.
        #expect(try await cache.digestHex(forFileAt: "/a", lastModified: touched, size: 11) { "third" } == "third")
    }

    @Test("Capacity configured on the server reaches the cache")
    func testConfiguredCapacityIsUsed() async throws {
        // The cache is built with the application, so the capacity has to be configured up front —
        // setting it on `app.serverConfiguration` afterwards is too late to reach the cache.
        try await withApp(configuration: ServerConfiguration(eTagHashCacheCapacity: 1)) { app in
            let otherFile = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .appendingPathComponent("FileTests.swift")
                .path

            app.get("file-stream") { req -> Response in
                try await app.fileio.streamFile(at: #filePath, for: req, advancedETagComparison: true)
            }
            app.get("other") { req -> Response in
                try await app.fileio.streamFile(at: otherFile, for: req, advancedETagComparison: true)
            }

            try await app.test(method: .running) { runner in
                let first = try await runner.sendRequest(.get, "/file-stream")
                #expect(first.status == .ok)
                #expect(await app.fileETagHashCache.count == 1)

                // A second, different file: with room for one entry it replaces the first rather
                // than being cached alongside it.
                let second = try await runner.sendRequest(.get, "/other")
                #expect(second.status == .ok)
                #expect(await app.fileETagHashCache.count == 1)
                #expect(await app.fileETagHashCache.entry(forFileAt: otherFile) != nil)
            }
        }
    }

    @Test("The cache evicts the least recently used entry once it is full")
    func testEvictsLeastRecentlyUsed() async throws {
        let cache = FileETagHashCache(capacity: 2)

        _ = try await cache.digestHex(forFileAt: "/a", lastModified: modified, size: 1) { "a" }
        _ = try await cache.digestHex(forFileAt: "/b", lastModified: modified, size: 1) { "b" }
        // Use "/a" again so "/b" becomes the coldest entry.
        _ = try await cache.digestHex(forFileAt: "/a", lastModified: modified, size: 1) { "a" }
        _ = try await cache.digestHex(forFileAt: "/c", lastModified: modified, size: 1) { "c" }

        #expect(await cache.count == 2)
        #expect(await cache.entry(forFileAt: "/b") == nil)
        #expect(await cache.entry(forFileAt: "/a") != nil)
        #expect(await cache.entry(forFileAt: "/c") != nil)
    }
}
